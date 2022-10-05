using Test
using PackageCompiler
using AutoSysimages

if VERSION < v"1.9.0"
    @testset "Support pkgversion before Julia v1.9" begin
        @test AutoSysimages.pkgversion(PackageCompiler) > v"0.1.0"
    end
end

@testset "_warn_outdated() runs" begin
    @test isnothing(AutoSysimages._warn_outdated())
end

@testset "install()" begin
    if Sys.islinux() || Sys.isapple() || Sys.iswindows()
        tmp_dir = mktempdir()
        install(tmp_dir)
        file_name = Sys.iswindows() ? "asysimg.bat" : "asysimg"
        @test isfile(joinpath(tmp_dir, file_name))
    end
end

function run_and_get_last_line(cmd)
    out = readchomp(cmd)
    sp = split(out, "\n")
    length(sp) > 0 ? sp[end] : ""
end

@testset "install and run asysimg, test --project argument" begin
    plots_exemple = abspath("../examples/ExampleWithPlots")
    @test ispath(plots_exemple)
    for proj in ["-q", "", plots_exemple]
        if Sys.islinux() || Sys.isapple() || Sys.iswindows()
            tmp_dir = mktempdir()
            install(tmp_dir)
            file_name = Sys.iswindows() ? "asysimg.bat" : "asysimg"
            asysimg_path = joinpath(tmp_dir, file_name)
            @test isfile(asysimg_path)
            original_sysimage = unsafe_string(Base.JLOptions().image_file)
            proj_exec = proj == "-q" ? `-q` : (proj == "" ? `--project` : `--project="$proj"`)
            sysimage = run_and_get_last_line(`$asysimg_path "$proj_exec" -e "using AutoSysimages; println(AutoSysimages._generate_sysimage_name()); exit();"`)
            @show sysimage
            cp(original_sysimage, sysimage, force = true)
            # Test the argument contains the sysimage
            args = run_and_get_last_line(`$asysimg_path "$proj_exec" -e "using AutoSysimages; using AutoSysimages; println(julia_args()); exit();"`)
            @test contains(args, sysimage)
            # Test if the sysimage is really loaded
            cmd = `$asysimg_path $proj_exec -e "using AutoSysimages; AutoSysimages.is_asysimg || exit(1);"`
            @show cmd
            run(cmd) # Show the error, if some
            @test success(cmd)
            rm(sysimage; force = true)
        end
    end
end
