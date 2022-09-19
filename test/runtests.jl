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

@testset "install and run asysimg, default project" begin
    @test ispath("../examples/ExampleWithPlots")
    for proj in ["-q", "--project", "--project=../examples/ExampleWithPlots"]
        @show proj
        if Sys.islinux() || Sys.isapple() || Sys.iswindows()
            tmp_dir = mktempdir()
            install(tmp_dir)
            file_name = Sys.iswindows() ? "asysimg.bat" : "asysimg"
            asysimg_path = joinpath(tmp_dir, file_name)
            @test isfile(asysimg_path)
            original_sysimage = unsafe_string(Base.JLOptions().image_file)
            sysimage = run_and_get_last_line(`$asysimg_path "$proj" -e "using AutoSysimages; println(AutoSysimages._generate_sysimage_name()); exit();"`)
            @show sysimage
            #touch(sysimage)
            symlink(original_sysimage, sysimage)
            args = run_and_get_last_line(`$asysimg_path "$proj" -e "using AutoSysimages; using AutoSysimages; println(julia_args()); exit();"`)
            @show args
            @test contains(args, sysimage)
            rm(sysimage)
        end
    end
end
