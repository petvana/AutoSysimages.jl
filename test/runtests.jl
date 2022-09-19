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
