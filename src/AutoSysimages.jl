module AutoSysimages

using REPL
using LLVM_full_jll
using Pkg
using Pidfile
using Dates
using PackageCompiler
using TOML

export start, latest_sysimage, julia_args, build_sysimage, remove_old_sysimages
export packages_to_include, set_packages, status, add, remove

active_dir = ""
precompiles_file = ""
is_asysimg = false

snoop_file = nothing
snoop_file_io = nothing

background_task = nothing

function __init__()
    global background_task_lock = ReentrantLock()
    # Set global variables
    global project_path = Base.active_project()
    global preferences_path = joinpath(dirname(project_path), "SysimagePreferences.toml")
    # Create short directory name
    hash_name = string(hash(project_path), base = 62, pad = 11)
    global active_dir = joinpath(DEPOT_PATH[1], "asysimg", "$VERSION", hash_name)
    # TODO - do not create dir in `__init__`
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
        if isnothing(_load_preference("include"))
            _set_preference!("include" => [])
            _set_preference!("exclude" => [])
        end
        is_asysimg && VERSION >= v"1.8" && _warn_outdated()
    end
end

"""
    build_sysimage(background::Bool = false)

Build new system image (in `background`) for the current project including snooped precompiles.
"""
function build_sysimage(background::Bool = false)
    if background
        global background_task_lock
        lock(background_task_lock) do
            global background_task
            if isnothing(background_task) || Base.istaskdone(background_task)
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

"""
    set_packages()

Ask the user to choose which packages to include into the sysimage.
"""
function set_packages()
    # TODO - ask user (and print him/her all the options)
    _set_preference!("include" => ["OhMyREPL"])
end

"""
    add(package::String)

Set package to be included into the system image.
"""
function add(package::String)
    include = _load_preference("include")
    exclude = _load_preference("exclude")
    if !isnothing(include) && include isa Vector{String}
        # Add to the `include` list
        package ∉ include && push!(include, package)
        _set_preference!("include" => include)
    else
        if isnothing(exclude) || !(exclude isa Vector{String})
            _set_preference!("include" => [package])
        end
    end
    # Remove from the `exclude` list
    if !isnothing(exclude) && exclude isa Vector{String}
        filter!(!isequal(package), exclude)
        _set_preference!("exclude" => exclude)
    end
end

"""
    remove(package::String)

Set package to be excluded into the system image.
"""
function remove(package::String)
    include = _load_preference("include")
    if !isnothing(include) && include isa Vector{String}
        # Remove from the `include` list
        filter!(!isequal(package), include)
        _set_preference!("include" => include)
    else
        # Add to the `exclude` list
        exclude = _load_preference("exclude")
        if !isnothing(exclude) && exclude isa Vector{String}
            push!(exclude, package)
            _set_preference!("exclude" => exclude)
        else
            exclude = [package]
        end
        _set_preference!("exclude" => exclude)
    end
end

"""
    packages_to_include()::Set{String}

Get list of packages to be included into sysimage.
It is determined based on "include" or "exclude" options save by `Preferences.jl` 
in `LocalPreferences.toml` file next to the currently-active project.
"""
function packages_to_include()
    packages = Set(keys(Pkg.project().dependencies))
    include = _load_preference("include")
    exclude = _load_preference("exclude")
    if !isnothing(include)
        if include isa Vector{String}
            if !isempty(include)
                packages = Set(include)
            end
        else
            if !(include isa Vector) || !isempty(include)
                @warn "Incorrect format of \"include\" in LocalPreferences.toml file."
            end
        end
    end
    if !isnothing(exclude)
        if exclude isa Vector{String}
            for e in exclude
                delete!(packages, e)
            end
        else
            if !(exclude isa Vector) || !isempty(exclude)
                @warn "Incorrect format of \"exclude\" in LocalPreferences.toml file."
            end
        end
    end
    return packages
end

"""
    status()

Print list of packages to be included into sysimage determined by `packages_to_include`.
"""
function status()
    if Base.have_color
        printstyled("    Project ", color = :magenta)
    else
        print("    Project ")
    end
    println("`$project_path`")
    if Base.have_color
        printstyled("   Settings ", color = :magenta)
    else
        print("   Settings ")
    end
    println("`$preferences_path`")

    println("Packages to be included into sysimage:")
    versions = Dict{String, Tuple{Any, Any}}()
    for d in Pkg.dependencies()
        uuid = d.first
        version = d.second.version
        name = d.second.name
        versions[name] = (uuid, version)
    end
    packages = packages_to_include()
    for name in packages
        if !isnothing(get(versions, name, nothing))
            uuid, version = versions[name]
            if Base.have_color
                printstyled("  [", string(uuid)[1:8], "] "; color = :light_black)
            else
                print("  [", string(uuid)[1:8], "] ")
            end
            println("$name v$version")
        else
            @warn "Package $name is not in the project and cannot be included in sysimg."
        end
    end
end

function _warn_outdated()
    if VERSION < v"1.8"
        @warn "Julia v1.8+ is needed to check package versions."
        return
    end
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
    if !is_asysimg
        println("There is no sysimage for this project. Do you want to build one?")
        if REPL.TerminalMenus.request(REPL.TerminalMenus.RadioMenu(["yes", "no"])) == 1
            build_sysimage()
        end
    end
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
        if Base.have_color
            mode.prompt_prefix = Base.text_colors[isbuilding ? :red : :magenta]
        end
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
    t = Dates.now()
    sysimg_file = "$active_dir/asysimg-$t.so"
    chained = false
    try 
        # Enable chained building of system image
        # See https://github.com/JuliaLang/julia/pull/46045
        @ccall jl_precompiles_for_sysimage(1::Cuchar)::Cvoid;
        chained = true
    catch 
    end
    if chained
        _build_system_image_chained(sysimg_file)
    else
        _build_system_image_package_compiler(sysimg_file)
    end
end

function _build_system_image_package_compiler(sysimg_file)
    @info "Building system image by PackageCompiler."
    packages = Symbol.(packages_to_include())
    precompile_file_path = joinpath(@__DIR__, "precompile-PackageCompiler.jl")
    create_sysimage(packages, sysimage_path = sysimg_file, script = precompile_file_path)
end

function _build_system_image_chained(sysimg_file)
    # Get path to compilation tools from LLVM_full_jll
    llvm_config = LLVM_full_jll.get_llvm_config_path()
    objcopy = replace(llvm_config, "llvm-config" => "llvm-objcopy")
    ar = replace(llvm_config, "llvm-config" => "llvm-ar")
    clang = replace(llvm_config, "llvm-config" => "clang")

    mktempdir() do chained_dir
        @info "Building chained system image in $chained_dir"
        mkpath(active_dir)
        cd(chained_dir)
        cp("$(DEPOT_PATH[3])/../../lib/julia/sys-o.a", "sys-o.a", force=true)
        run(`$ar x sys-o.a`)
        run(`rm data.o`)
        run(`mv text.o text-old.o`)
        run(`$objcopy --remove-section .data.jl.sysimg_link text-old.o`) # rm the link between the native code and 
        cd("..")

        using_packages = ""
        for name in packages_to_include()
            using_packages *= " using $name;"
        end

        precompile_file_path = joinpath(@__DIR__, "precompile.jl")
        source_txt = """
Base.__init_build();

module PrecompileStagingArea;
$using_packages
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
        julia_so = "$julia_dir/../lib/julia/sys.so"
        run(`$julia_cmd --project=$project_path --sysimage-native-code=chained --sysimage=$julia_so --output-o $chained_dir/chained.o.a -e $source_txt`)

        cd(chained_dir)
        run(`$ar x chained.o.a`) # Extract new sysimage files
        run(`$clang -shared -o $sysimg_file text.o data.o text-old.o`)
        cd("..")
        @info "New sysimage $sysimg_file generated."
        @info "Restart of Julia is necessary to load the new sysimage."
    end
    remove_old_sysimages()
end

function _set_preference!(pair::Pair{String, T}) where T
    if isfile(preferences_path)
        project = Base.parsed_toml(preferences_path)
    else
        project = Dict{String,Any}()
    end
    if !haskey(project, "AutoSysimages")
        project["AutoSysimages"] = Dict{String,Any}()
    end
    project["AutoSysimages"][pair.first] = pair.second
    open(preferences_path, "w") do io
        TOML.print(io, project; sorted=true)
    end
end

function _load_preference(key::String)
    !isfile(preferences_path) && return nothing
    project = Base.parsed_toml(preferences_path)
    if haskey(project, "AutoSysimages")
        dict = project["AutoSysimages"]  
        if dict isa Dict
            return get(dict, key, nothing)
        end
    end
    return nothing
end

end # module
