function _build_system_image_package_compiler(sysimg_file)
    @info "AutoSysimages: Building system image by PackageCompiler."
    packages = Symbol.(packages_to_include())
    precompile_file_path = joinpath(@__DIR__, "precompile-PackageCompiler.jl")
    create_sysimage(packages, sysimage_path = sysimg_file, script = precompile_file_path)
end