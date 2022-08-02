module AutoSysimages

using Preferences
using REPL
using LLVM_full_jll
using Pkg
using Pidfile
using Dates

export build_sysimage

active_dir = ""
precompiles_file = ""
is_asysimg = false

snoop_file = nothing
snoop_file_io = nothing

building_task = nothing

function __init__()
    global building_task_lock = ReentrantLock()
    # Set global variables
    project_path = Pkg.project().path
    hash_name = string(hash(project_path), base = 62, pad = 11)
    asysimg_dir = joinpath(DEPOT_PATH[1], "asysimg")
    global active_dir = joinpath(asysimg_dir, "$VERSION", hash_name)
    if !isdir(active_dir)
        mkpath(active_dir)
        # Print information about the project
        open(joinpath(active_dir, "project-path.txt"), "w") do io
            print(io, "$project_path\n")
        end
    end
    global precompiles_file =  joinpath(active_dir, "snoop-file.jl")
    image = unsafe_string(Base.JLOptions().image_file)
    # Detect if loaded `image` was produced by AutoSysimages.jl
    global is_asysimg = startswith(basename(image), "asysimg-")
    if is_asysimg
        # Prevent the sysimage to be removed during Julia execution
        global _pidlock = mkpidlock("$image.$(getpid())")
    end
end

"""
    latest_sysimage()

Return the path to the latest system image produced by AutoSysimages,
or `nothing` if no such image exits.
"""
function latest_sysimage()
    files = readdir(active_dir, join = true)
    sysimages = filter(x -> endswith(x, ".so"), files) |> sort
    return isempty(sysimages) ? nothing : sysimages[end]
end

"""
    julia_args()

Get Julia arguments for running AutoSysimages:
- `"-J [sysimage]"` - sets the `latest_sysimage()`, if it exits,
- `"-L [@__DIR__]/start.jl"` - starts AutoSysimages automatically.
"""
function julia_args()
    image = latest_sysimage()
    startfile = joinpath(@__DIR__, "start.jl")
    return (isnothing(image) ? "" : " -J $image") * " -L $startfile" 
end

"""
    start()

Starts AutoSysimages package. It's usually called by `start.jl` file;
but it can be called manually as well.
"""
function start()
    _start_snooping()
    @info "AutoSysimages: Using directory $active_dir"
    if isinteractive()
        _update_prompt()
        if !is_asysimg
            # TODO - improve the logic for autonomic rebuild
            # @set_preferences!("autobuild" => "yes")
            # @load_preference("autobuild")
            println("There is no sysimage for this project. Do you want to build it?")
            if REPL.TerminalMenus.request(REPL.TerminalMenus.RadioMenu(["yes", "no"])) == 1
                build_sysimage()
            end
        else
            _warn_outdated()
        end
    end
end

"""
    build_sysimage(background::Bool = true)

Build new system image (in `background`) for the current project including snooped precompiles.
"""
function build_sysimage(background::Bool = true)
    if background
        lock(building_task_lock) do
            global building_task
            if isnothing(building_task) || Base.istaskdone(building_task)
                building_task = @task _build_system_image()
                schedule(building_task)
            else
                @warn "System image is already being build!"
            end
        end
    else
        _build_system_image()
    end
end

"""
    remove_old_sysimages()

Remove old sysimages for the current project (`active_dir`).
"""
function remove_old_sysimages()
    mkpidlock(joinpath(active_dir, "rm.lock")) do
        files = readdir(active_dir, join = true)
        sysimages = filter(x -> endswith(x, ".so"), files)
        latest = latest_sysimage()
        for si in sysimages
            locks = filter(x -> startswith(x, si), files)
            if length(locks) == 1 && si != latest
                @info "AutoSysimages: Removing old sysimage $si"
                rm(si)
            end
        end
    end
end

function _warn_outdated()
    versions = Dict{Base.UUID, VersionNumber}()
    outdated = Tuple{String, VersionNumber, VersionNumber}[]
    for d in Pkg.dependencies()
        uuid = d.first
        version = d.second.version
        isnothing(version) || (versions[uuid] = version)
    end
    for l in Base.loaded_modules
        uuid = l.first.uuid
        version = pkgversion(l.second)
        dep_version = get(versions, uuid, version)
        if dep_version != version
            push!(outdated, (l.first.name, version, dep_version))
        end
    end
    if !isempty(outdated)
        txt = "Some packages are outdated. Consider calling build_sysimage()."
        for out in outdated
            txt *= "\n - $(out[1]): $(out[2]) -> $(out[3])"
        end
        @warn txt
    end
end

function _start_snooping()
    global snoop_file_io
    if snoop_file_io === nothing
        global snoop_file = "$(tempname())-snoop.jl"
        mkpath(dirname(snoop_file))
        @info("Snooping -> $(snoop_file)")
        global snoop_file_io = open(snoop_file, "w")
        ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), snoop_file_io.handle)
        atexit(_stop_snooping)
    else
        @warn("Snooping is already running -> $(snoop_file)")
    end
end

function _stop_snooping()
    global snoop_file_io
    if isnothing(snoop_file_io)
        @warn("No active snooping file")
        return 
    end
    ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), C_NULL)
    close(snoop_file_io)
    snoop_file_io = nothing
    _save_statements()
    isfile(snoop_file) && rm(snoop_file)
end

function _flush_statements()
    !isnothing(snoop_file_io) && flush(snoop_file_io)
end

function _save_statements()
    _flush_statements()
    lines = readlines(snoop_file)
    act_precompiles = String[]
    open("$(snoop_file).txt", "w") do file
        for line in lines
            sp = split(line, "\t")
            if length(sp) == 2
                push!(act_precompiles, sp[2][2:end-1])
            end          
        end
    end

    global precompiles_file
    @info("Copy snooped function into $(precompiles_file)")
    @time mkpidlock("$precompiles_file.lock") do
        oldprec = isfile(precompiles_file) ? readlines(precompiles_file) : String[]
        old = Set{String}(oldprec)
        open(precompiles_file, "a") do file
            for precompile in act_precompiles
                if precompile ∉ old
                    push!(old, precompile)
                    write(file, "$precompile\n")   
                end     
            end
        end
    end
end

# TODO - make it compatible with OhMyREPL
function _update_prompt(isbuilding::Bool = false)
    function _update_prompt(repl::AbstractREPL)
        mode = repl.interface.modes[1]
        mode.prompt = "asysimg> "
        mode.prompt_prefix = Base.text_colors[isbuilding ? :red : :magenta]
    end
    repl = nothing
    if isdefined(Base, :active_repl) && isdefined(Base.active_repl, :interface)
        repl = Base.active_repl
        _update_prompt(repl)
    else
        atreplinit() do repl
            if !isdefined(repl, :interface)
                repl.interface = REPL.setup_interface(repl)
            end
            _update_prompt(repl)
        end
    end
end

function _build_system_image()
    # Get path to compilation tools from LLVM_full_jll
    llvm_config = LLVM_full_jll.get_llvm_config_path()
    objcopy = replace(llvm_config, "llvm-config" => "llvm-objcopy")
    ar = replace(llvm_config, "llvm-config" => "llvm-ar")
    clang = replace(llvm_config, "llvm-config" => "clang")

    mktempdir() do chained_dir
        @info "Building system image in $chained_dir"    
        mkpath(active_dir)
        cd(chained_dir)
        cp("$(DEPOT_PATH[3])/../../lib/julia/sys-o.a", "sys-o.a", force=true)
        run(`$ar x sys-o.a`)
        run(`rm data.o`)
        run(`mv text.o text-old.o`)
        run(`$objcopy --remove-section .data.jl.sysimg_link text-old.o`) # rm the link between the native code and 
        cd("..")

        precompile_file_path = joinpath(@__DIR__, "precompile.jl")
        source_txt = """
Base.__init_build();

module PrecompileStagingArea;
    # using AutoSysimages
    # TODO - load libraries
end;
    """
        source_txt *= """
@ccall jl_precompiles_for_sysimage(1::Cuchar)::Cvoid;
include("$precompile_file_path")
    """

        if isfile(precompiles_file)
            cp(precompiles_file, "statements.txt", force=true)
        end
        #julia_cmd = get_julia_path()
        julia_cmd = joinpath(Sys.BINDIR::String, Base.julia_exename())
        julia_dir = dirname(julia_cmd)
        @show julia_cmd
        julia_so = "$julia_dir/../lib/julia/sys.so"
        run(`$julia_cmd --sysimage-native-code=chained --sysimage=$julia_so --output-o $chained_dir/chained.o.a -e $source_txt`)

        cd(chained_dir)
        t = Dates.now()
        autosysimages_image = "$active_dir/asysimg-$t.so"
        run(`$ar x chained.o.a`) # Extract new sysimage files
        run(`$clang -shared -o $autosysimages_image text.o data.o text-old.o`)
        cd("..")
        @info "New sysimage $autosysimages_image generated."
        @warn "Restart of Julia is necessary to load the new sysimage."
    end
    remove_old_sysimages()
end


end # module
