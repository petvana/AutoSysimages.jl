module AutoSysimages

#using Preferences
using REPL
using LLVM_full_jll
using Pkg
using Pidfile
using Dates

const PROJECT_ROOT = @__DIR__

autosysimages_dir = nothing
global_snoop_file = nothing
snoop_file = nothing
snoop_file_io = nothing
project_path = nothing

function get_sysimage()
    set_sysimage_dir()
    !isdir(autosysimages_dir) && return nothing
    files = readdir(autosysimages_dir, join = true)
    sysimages = filter(x -> endswith(x, ".so"), files) |> sort
    return isempty(sysimages) ? nothing : sysimages[end]
end

function get_autosysimage_args()
    autosysimages_image = get_sysimage()
    args = ""
    if !isnothing(autosysimages_image)
        args *= " -J $autosysimages_image"
    end
    return args * " -L $PROJECT_ROOT/start.jl"
end

function set_sysimage_dir()
    global project_path = Pkg.project().path
    project_hash = hash(project_path)
    global autosysimages_dir =
        "$(DEPOT_PATH[1])/autosysimages/v$(VERSION.major).$(VERSION.minor)/$project_hash"
    global global_snoop_file =  joinpath(autosysimages_dir, "snoop-file.jl")
end

function start()
    @info "Package AutoSysimages started."
    # @show autosysimages_image
    # @show isfile(autosysimages_image)
    set_sysimage_dir()
    if !isdir(autosysimages_dir)
        mkpath(autosysimages_dir)
        open("$autosysimages_dir/pathtoproject.txt", "w") do io
            print(io, "$project_path\n")
        end
    end
    start_snooping()
    @info "AutoSysimages: Using directory $autosysimages_dir"
    if isinteractive()
        # TODO - find better way to detect generated sysimage
        if !endswith(unsafe_string(Base.JLOptions().image_file), "chained.so")
            println("There is no sysimage for this project. Do you want to build it?")
            if REPL.TerminalMenus.request(REPL.TerminalMenus.RadioMenu(["yes", "no"])) == 1
                build_system_image()
            end
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
            mkpath(autosysimages_dir)
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

llvm_config = LLVM_full_jll.get_llvm_config_path()
objcopy = replace(llvm_config, "llvm-config" => "llvm-objcopy")
ar = replace(llvm_config, "llvm-config" => "llvm-ar")
clang = replace(llvm_config, "llvm-config" => "clang")

function build_system_image()
    mktempdir() do chained_dir
        @info "Building system image in $chained_dir"    
        mkpath(autosysimages_dir)
        cd(chained_dir)
        cp("$(DEPOT_PATH[3])/../../lib/julia/sys-o.a", "sys-o.a", force=true)
        run(`$ar x sys-o.a`)
        run(`rm data.o`)
        run(`mv text.o text-old.o`)
        run(`$objcopy --remove-section .data.jl.sysimg_link text-old.o`) # rm the link between the native code and 
        cd("..")

        precompile_file_path = "$PROJECT_ROOT/precompile.jl"

        source_txt = "Base.__init_build();"
        source_txt *= """
module PrecompileStagingArea;
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
        autosysimages_image = "$autosysimages_dir/sys-$t.so"
        run(`$ar x chained.o.a`) # Extract new sysimage files
        run(`$clang -shared -o $autosysimages_image text.o data.o text-old.o`)
        cd("..")
        @info "New sysimage $autosysimages_image generated."
        @warn "Restart of Julia is necessary to load the new sysimage."
    end
    # TODO - remove old sysimages
end

end # module
