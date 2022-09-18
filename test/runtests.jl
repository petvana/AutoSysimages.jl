using Test
using PackageCompiler
using AutoSysimages

if VERSION < v"1.9.0"
    @testset "Support pkgversion before Julia v1.9" begin
        @test AutoSysimages.pkgversion(PackageCompiler) > v"0.1.0"
    end
end