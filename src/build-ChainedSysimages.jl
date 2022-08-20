function _build_system_image_chained(sysimg_file)
    # Get path to compilation tools from LLVM_full_jll
    llvm_config = LLVM_full_jll.get_llvm_config_path()
    objcopy = replace(llvm_config, "llvm-config" => "llvm-objcopy")
    ar = replace(llvm_config, "llvm-config" => "llvm-ar")
    clang = replace(llvm_config, "llvm-config" => "clang")

    # Currently used julia
    julia_cmd = joinpath(Sys.BINDIR::String, Base.julia_exename())
    julia_dir = dirname(julia_cmd)
    julia_so = "$julia_dir/../lib/julia/sys.so"

    # Prepare packages to be included
    using_packages = ""
    for name in packages_to_include()
        using_packages *= " using $name;"
    end

    # First make sure all the packages are precompiled
    # TODO - enable precompilation while builing chained sysiamge
    @info "AutoSysimages: Making sure that all packages are precompiled"
    source_txt = """  
    module PrecompileStagingArea;
        $using_packages
    end;
    """
    run(`$julia_cmd --project=$project_path --sysimage=$julia_so -e $source_txt`)

    mktempdir() do chained_dir
        @info "AutoSysimages: Building chained system image in $chained_dir"
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