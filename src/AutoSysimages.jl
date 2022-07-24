module AutoSysimages

using Preferences
using REPL
using LLVM_full_jll
using Pkg
using Pidfile
using Dates

project_path::String = ""
active_dir::String = ""
global_snoop_file::String = ""

snoop_file = nothing
snoop_file_io = nothing

building_task = nothing
building_task_lock = ReentrantLock()

function __init__()
    global project_path = Pkg.project().path
    project_hash = hash(project_path)
    global active_dir = "$(DEPOT_PATH[1])/autosysimages/v$(VERSION.major).$(VERSION.minor)/$project_hash"
    global global_snoop_file =  joinpath(active_dir, "snoop-file.jl")
end

function latest_sysimage()
    files = readdir(active_dir, join = true)
    sysimages = filter(x -> endswith(x, ".so"), files) |> sort
    return isempty(sysimages) ? nothing : sysimages[end]
end

function get_julia_args()
    image = latest_sysimage()
    startfile = joinpath(@__DIR__, "start.jl")
    return (isnothing(image) ? "" : " -J $image") * " -L $startfile" 
end

# TODO - use this, asynchronously?
function update_prompt(isbuilding::Bool = false)
    if isdefined(Base, :active_repl) && isdefined(Base.active_repl, :interface) 
        mode = Base.active_repl.interface.modes[1]
        mode.prompt = "jusim> "
        mode.prompt_prefix = Base.text_colors[isbuilding ? :red : :blue]
    end
end

"""
    start()

This starts AutoSysimages package.
"""
function start()
    @info "Package AutoSysimages started."
    if !isdir(active_dir)
        mkpath(active_dir)
        open("$active_dir/pathtoproject.txt", "w") do io
            print(io, "$project_path\n")
        end
    end
    start_snooping()
    @info "AutoSysimages: Using directory $active_dir"
    if isinteractive()
        sysimage_dir = "$(DEPOT_PATH[1])/autosysimages"
        image_file = unsafe_string(Base.JLOptions().image_file)
        if !startswith(image_file, sysimage_dir)
            println("There is no sysimage for this project. Do you want to build it?")
            if REPL.TerminalMenus.request(REPL.TerminalMenus.RadioMenu(["yes", "no"])) == 1
                build_system_image()
            end
        else
            # Lock the system image not to be deleted.
            pid = getpid()
            lock_file = "$image_file.$pid"
            @info "Lock $lock_file"
            # Strore in global variable to preserve during whole run
            global pidlock = mkpidlock(lock_file)
        end
    end
end

function start_snooping()
    global snoop_file_io
    if snoop_file_io === nothing
        global snoop_file = "$(tempname())-snoop.jl"
        mkpath(dirname(snoop_file))
        @info("Snooping -> $(snoop_file)")
        global snoop_file_io = open(snoop_file, "w")
        ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), snoop_file_io.handle)
        atexit(finish_snooping)
    else
        @warn("Snooping is already running -> $(snoop_file)")
    end
end

function finish_snooping()
    global snoop_file_io
    try
        if snoop_file_io === nothing
            @warn("No active snooping file")
            return 
        end
        ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), C_NULL)
        close(snoop_file_io)
        snoop_file_io = nothing
        save_statements()
        rm("$(snoop_file)")
    catch e
        @warn(e)
    end
end

function save_statements()
    try
        if snoop_file_io !== nothing
            flush(snoop_file_io)
        end       
        lines = readlines("$(snoop_file)")
        open("$(snoop_file).txt", "w") do file
            for line in lines
                sp = split(line, "\t")
                if length(sp) == 2
                    function_str = sp[2][2:end-1]
                    write(file, function_str * "\n")
                end          
            end
        end

        @info("Copy snooped function into $(global_snoop_file)")
        if isfile(global_snoop_file)
            # TODO - reimplement to Julia
            run(`sort $(snoop_file).txt $(global_snoop_file) -o $(global_snoop_file).tmp`)
        else
            # TODO - reimplement to Julia
            mkpath(active_dir)
            run(`sort $(snoop_file).txt -o $(global_snoop_file).tmp`)
        end
        # TODO - reimplement to Julia
        run(pipeline(`uniq $(global_snoop_file).tmp`, stdout="$(global_snoop_file)"))
        rm("$(snoop_file).txt")
        rm("$(global_snoop_file).tmp")
    catch e
        @warn(e)
    end
end

#=
set_julia_path(new_path) = @set_preferences!("julia_path" => new_path)

get_julia_path() = something(
    @load_preference("julia_path"), 
    joinpath(Sys.BINDIR::String, Base.julia_exename())
)
=#

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

        if isfile(global_snoop_file)
            cp(global_snoop_file, "statements.txt", force=true)
        end
        #julia_cmd = get_julia_path()
        julia_cmd = joinpath(Sys.BINDIR::String, Base.julia_exename())
        julia_dir = dirname(julia_cmd)
        @show julia_cmd
        julia_so = "$julia_dir/../lib/julia/sys.so"
        run(`$julia_cmd --sysimage-native-code=chained --sysimage=$julia_so --output-o $chained_dir/chained.o.a -e $source_txt`)

        cd(chained_dir)
        t = Dates.now()
        autosysimages_image = "$active_dir/sys-$t.so"
        run(`$ar x chained.o.a`) # Extract new sysimage files
        run(`$clang -shared -o $autosysimages_image text.o data.o text-old.o`)
        cd("..")
        @info "New sysimage $autosysimages_image generated."
        @warn "Restart of Julia is necessary to load the new sysimage."
    end
    remove_unused_sysimages()
end

function build_system_image()
    lock(building_task_lock) do
        global building_task
        if isnothing(building_task) || Base.istaskdone(building_task)
            building_task = @task _build_system_image()
            schedule(building_task)
        else
            @warn "No" # TODO
        end
    end
end

function remove_unused_sysimages()
    !isdir(active_dir) && return
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

end # module
