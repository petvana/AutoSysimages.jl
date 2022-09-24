module AutoSysimages

using REPL
using LLVM_full_jll
using Pkg
using Pidfile
using Dates
using PackageCompiler
using TOML

import Base: active_project
import REPL:
    REPL.TerminalMenus.request,
    REPL.TerminalMenus.RadioMenu,
    REPL.TerminalMenus.MultiSelectMenu

export start, latest_sysimage, julia_args, build_sysimage, remove_old_sysimages
export packages_to_include, select_packages, status, add, remove, active_dir, install

include("snooping.jl")
include("build-PackageCompiler.jl")
include("build-ChainedSysimages.jl")

# TODO: This can be removed once Julia 1.9+ is required
# This should not happen before v1.9+ becomes LTS.
include("pkgversion.jl")

precompiles_file = ""
is_asysimg = false

background_task = nothing

function __init__()
    global background_task_lock = ReentrantLock()
    # Set global variables
    projpath = active_project()
    if !isfile(projpath)
        @error "Project file do not exist: $projpath"
        return
    end
    # Create short directory name
    adir = active_dir(projpath)
    project_path_file = joinpath(adir, "project-path.txt")
    if !isfile(project_path_file)
        open(project_path_file, "w") do io
            print(io, "$projpath\n")
        end
    end
    global precompiles_file = joinpath(adir, "snoop-file.jl")
    global loaded_image = unsafe_string(Base.JLOptions().image_file)
    # Detect if loaded `image` was produced by AutoSysimages.jl
    global is_asysimg = startswith(basename(loaded_image), "asysimg-")
    if is_asysimg
        # Prevent the sysimage to be removed during Julia execution.
        # It needs to be global in order exist for the whole Julia session.
        global _pidlock = mkpidlock("$loaded_image.$(getpid())")
    end
end

"""
    active_dir()

Get directory where the sysimage and precompiles are stored for the current project.
The directory is created if it doesn't exist yet.
"""
function active_dir(projpath = active_project())
    hash_name = string(Base._crc32c(projpath), base = 62, pad = 6)
    adir = joinpath(DEPOT_PATH[1], "asysimg", "$VERSION", hash_name)
    !isdir(adir) && mkpath(adir)
    return adir
end

"""
    preferences_path()

Get the file with preferences for the active project (`active_dir()`).
Preferences are stored in `SysimagePreferences.toml` next to the current `Project.toml` file.
"""
preferences_path(projpath = active_project()) =
    joinpath(dirname(projpath), "SysimagePreferences.toml")

"""
    latest_sysimage()

Return the path to the latest system image produced by AutoSysimages,
or `nothing` if no such image exits.
"""
function latest_sysimage(adir = active_dir())
    !isdir(adir) && return nothing
    files = readdir(adir, join = true)
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
    if !isfile(active_project())
        @error "Project file do not exist: $projpath"
        return
    end
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
    isfile(active_project()) || return
    Snooping.start_snooping()
    function _atexit()
        statements = Snooping.stop_snooping()
        @info("AutoSysimages: Copy snooped statements to: $(precompiles_file)")
        _append_statements(statements)
        if !is_asysimg && isinteractive()
            @info "There is no sysimage for this project. Do you want to build one?"
            if request(RadioMenu(["Yes", "No"])) == 1
                build_sysimage()
            end
        end
    end
    atexit(_atexit)
    if Base.JLOptions().quiet == 0 # Disabled when `-q` argument is used
        txt = "The package AutoSysimages.jl started!"
        if is_asysimg
            txt *= "\n Loaded sysimage:    $loaded_image"
        else
            txt *= "\n Loaded sysimage:    Default (You may run AutoSysimages.build_sysimage())"
        end
        txt *= "\n Active directory:   $(active_dir())"
        txt *= "\n Global snoop file:  $precompiles_file"
        txt *= "\n Tmp. snoop file:    $(Snooping.snoop_file)"
        @info txt
    end
    if isinteractive()
        _update_prompt()
        is_asysimg && _warn_outdated()
    end
end

"""
    build_sysimage(background::Bool = false)

Build new system image (in `background`) for the current project including snooped precompiles.
"""
function build_sysimage(background::Bool = false)
    # Do not ask user to build sysimage again
    global is_asysimg = true

    # Check if the project is already set
    if isnothing(_load_preference("include"))
        if isinteractive()
            @info """AutoSysimages: No project settings (SysimagePreferences.toml) found.
Do you want to select packages to be included now?"""
            if request(RadioMenu(["Yes (select packages)", "No (include all packages)"])) == 1
                select_packages()
            else
                _set_preference!("include" => [])
                _set_preference!("exclude" => [])
            end
        else
            @info "AutoSysimages: No project settings (SysimagePreferences.toml) found."
        end
    end

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

Remove old sysimages for the current project (`active_dir()`).
"""
function remove_old_sysimages()
    adir = active_dir()
    mkpidlock(joinpath(adir, "rm.lock")) do
        files = readdir(adir, join = true)
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
    select_packages()

Ask the user to choose which packages to include into the sysimage.
"""
function select_packages()
    all_packages = packages_to_include(; include_all = true) |> collect |> sort
    @info "Please select packages to be included into sysimage:"
    include = _load_preference("include")
    exclude = _load_preference("exclude")
    selected = Int[]
    if include isa Vector{String}
        for (idx, package) in enumerate(all_packages)
            package ∈ include && push!(selected, idx)
        end
    elseif exclude isa Vector{String}
        for (idx, package) in enumerate(all_packages)
            package ∈ exclude || push!(selected, idx)
        end
    end
    user_selected = request(MultiSelectMenu(all_packages; selected = selected))
    _set_preference!("include" => all_packages[collect(user_selected)])
    _set_preference!("exclude" => [])
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
Notice `dev` packages are excluded unless they are in `include` list.
"""
function packages_to_include(; include_all = false)
    packages = Set{String}()
    include_AutoSysimages = false
    for (uuid, info) in Pkg.dependencies()
        if info.is_direct_dep && !info.is_tracking_path
            push!(packages, info.name)
        end
        # Include AutoSysimages only if it is not in "dev" mode
        if info.name == "AutoSysimages" && !info.is_tracking_path
            include_AutoSysimages = true
        end
    end
    include_all && return packages
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
    include_AutoSysimages && push!(packages, "AutoSysimages")
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
    println("`$(active_project())`")
    if Base.have_color
        printstyled("   Settings ", color = :magenta)
    else
        print("   Settings ")
    end
    println("`$(preferences_path())`")

    println("Packages to be included into sysimage:")
    infos = Dict{String,Tuple{Any,Pkg.API.PackageInfo}}()
    for (uuid, info) in Pkg.dependencies()
        infos[info.name] = (uuid, info)
    end
    packages = packages_to_include()
    for name in packages
        if !isnothing(get(infos, name, nothing))
            uuid, info = infos[name]
            if Base.have_color
                printstyled("  [", string(uuid)[1:8], "] "; color = :light_black)
            else
                print("  [", string(uuid)[1:8], "] ")
            end
            print("$name v$(info.version)")
            if info.is_tracking_path
                print(" \`$(info.source)\`")
            end
            println()
        else
            @warn "Package $name is not in the project and cannot be included in sysimg."
        end
    end
end

function _default_install_dir()
    if Sys.islinux()
        return joinpath(homedir(), ".local/bin")
    elseif Sys.isapple()
        return joinpath(homedir(), "bin")
    elseif Sys.iswindows()
        return Sys.BINDIR
    else
        return nothing
    end
end

"""
    install()

This install the `asysimg` scripts.
(Currently implemented only for Linux.)
"""
function install(dir = _default_install_dir())
    if isnothing(dir)
        @warn """AutoSysimages: Installation is not yet supported for your OS.
Feel free to submit a PR."""
        return
    end

    dir_exists = ispath(dir)
    dir_exists || mkpath(dir)

    (os, file_name) = Sys.iswindows() ? ("windows", "asysimg.bat") : ("unix", "asysimg")
    source = joinpath(@__DIR__, "..", "scripts", os, file_name)
    source = abspath(normpath(source))
    julia_bin = unsafe_string(Base.JLOptions().julia_bin)
    julia_args_file = joinpath(@__DIR__, "julia_args.jl")
    script_file = joinpath(dir, file_name)
    txt = if Sys.iswindows()
"""@echo off
set JULIA=$julia_bin
for /f "tokens=1-4" %%i in ('%JULIA% -L $julia_args_file') do set A=%%i %%j %%k %%l
%JULIA% %A% %*
"""
    else
"""#!/usr/bin/env bash
JULIA=$julia_bin
asysimg_args=`\$JULIA -L $julia_args_file "\$@"`
\$JULIA \$asysimg_args "\$@"
"""
    end
    open(script_file, "w") do file
        write(file, txt)
    end
    chmod(script_file, 0o774)

    if isinteractive()
        @info """AutoSysimages: The `asysimg` is located here:
$(script_file)

Now you can run `asysimg` in terminal (instead of `julia`)

"""
    end

    if !dir_exists
        @warn """AutoSysimages: Please restart your terminal before running `asysimg`
to load the script into the `PATH`.

If this not works please add the script into your `PATH`."""
    end

end

function _warn_outdated()
    versions = Dict{Base.UUID,VersionNumber}()
    outdated = Tuple{String,VersionNumber,VersionNumber}[]
    for (uuid, info) in Pkg.dependencies()
        version = info.version
        isnothing(version) || (versions[uuid] = version)
    end
    for l in Base.loaded_modules
        uuid = l.first.uuid
        version = pkgversion(l.second)
        dep_version = get(versions, uuid, version)
        if dep_version != version && !isnothing(version)
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

function _append_statements(precompiles::Vector{String})
    global precompiles_file
    mkpidlock("$precompiles_file.lock") do
        oldprec = isfile(precompiles_file) ? readlines(precompiles_file) : String[]
        old = Set{String}(oldprec)
        open(precompiles_file, "a") do file
            for precompile in precompiles
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
    t_start = time()
    datenow = replace("$(Dates.now())", ":" => "-")
    sysimg_file = joinpath(string(active_dir()), "asysimg-$datenow.so")

    # First collect precompile statements for a dummy run (e.g., with -e "")
    @info "AutoSysimages: Collecting precompile statements for empty run (-e \"\")"
    precompiles_file = tempname()
    run(`asysimg -J $loaded_image -e "" --trace-compile $precompiles_file`)
    if isfile(precompiles_file)
        precompiles = String[]
        for line in readlines(precompiles_file)
            if startswith(line, "precompile(") && endswith(line, ")")
                push!(precompiles, line[12:end-1])
            end
        end
        _append_statements(precompiles)
    end

    chained = false
    try
        # Enable chained building of system image
        # See https://github.com/JuliaLang/julia/pull/46045
        @ccall jl_precompiles_for_sysimage(1::Cuchar)::Cvoid
        chained = true
    catch
    end
    if chained
        _build_system_image_chained(sysimg_file)
    else
        _build_system_image_package_compiler(sysimg_file)
    end
    @info "AutoSysimages: Builded in $(time() - t_start) s"
    remove_old_sysimages()
end

function _set_preference!(pair::Pair{String,T}) where {T}
    prefpath = preferences_path()
    if isfile(prefpath)
        project = Base.parsed_toml(prefpath)
    else
        project = Dict{String,Any}()
    end
    if !haskey(project, "AutoSysimages")
        project["AutoSysimages"] = Dict{String,Any}()
    end
    project["AutoSysimages"][pair.first] = pair.second
    # Sort such that `include` and `exclude` are first
    function by_fce(x)
        x == "include" && return "1"
        x == "exclude" && return "2"
        return "3" * x
    end
    open(prefpath, "w") do io
        TOML.print(io, project; sorted = true, by = by_fce)
    end
end

function _load_preference(key::String)
    prefpath = preferences_path()
    !isfile(prefpath) && return nothing
    project = Base.parsed_toml(prefpath)
    if haskey(project, "AutoSysimages")
        dict = project["AutoSysimages"]
        if dict isa Dict
            return get(dict, key, nothing)
        end
    end
    return nothing
end

end # module
