function _build_system_image_chained(sysimg_file)
    # Get path to compilation tools from LLVM_full_jll
    llvm_config = LLVM_full_jll.get_llvm_config_path()
    objcopy = replace(llvm_config, "llvm-config" => "llvm-objcopy")
    ar = replace(llvm_config, "llvm-config" => "llvm-ar")
    clang = replace(llvm_config, "llvm-config" => "clang")

    # Currently used julia executable with sysimage
    julia_cmd = joinpath(Sys.BINDIR::String, Base.julia_exename())
    julia_dir = dirname(julia_cmd)
    julia_so = "$julia_dir/../lib/julia/sys.so"
    projpath = active_project()

    # Prepare packages to be included
    using_packages = ""
    for name in packages_to_include()
        using_packages *= " using $name;"
    end

    chained_dir = mktempdir(;cleanup = false)

    # First make sure all the packages are precompiled
    # TODO - enable precompilation while building chained sysimage
    @info "AutoSysimages: Making sure that all packages are precompiled"
    source_file1 = tempname(chained_dir)
    open(source_file1, "w") do file
        write(file,
"""
module PrecompileStagingArea;
    $using_packages
end;
"""
        )
    end
    run(`$julia_cmd --project=$projpath --sysimage=$julia_so $source_file1`)

    ok = false
    cd(chained_dir) do
        @info "AutoSysimages: Building chained system image in $chained_dir"
        active_dir()
        cp("$(DEPOT_PATH[3])/../../lib/julia/sys-o.a", "sys-o.a", force=true)
        run(`$ar x sys-o.a`)
        rm("data.o")
        mv("text.o", "text-old.o")
        run(`$objcopy --remove-section .data.jl.sysimg_link text-old.o`) # rm the link between the native code and 

        source_txt2 =
"""
Base.__init_build();

module PrecompileStagingArea;
$using_packages
end;

@ccall jl_precompiles_for_sysimage(1::Cuchar)::Cvoid;
include("$(joinpath(@__DIR__, "precompile.jl"))")
"""

        source_file2 = tempname(chained_dir)
        open(source_file2, "w") do file
            write(file, source_txt2)
        end

        isfile(precompiles_file) && cp(precompiles_file, "statements.txt", force=true)
        run(`$julia_cmd --project=$projpath --sysimage-native-code=chained --sysimage=$julia_so --output-o $chained_dir/chained.o.a $source_file2`)

        run(`$ar x chained.o.a`) # Extract new sysimage files
        ok = success(`$clang -shared -o $sysimg_file text.o data.o text-old.o`)
        @info "AutoSysimages: New sysimage $sysimg_file generated."
        @info "AutoSysimages: Restart of Julia is necessary to load the new sysimage."
    end
    if ok
        rm(chained_dir, recursive=true)
    else
        @warn "The compilation was not successful. All the files are stored in $chained_dir"
    end
    remove_old_sysimages()
end