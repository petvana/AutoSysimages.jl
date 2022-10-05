# This mimics the `julia_args` function for fast startup.
# It needs to be kept in sync with the functions!

startfile = joinpath(@__DIR__, "start.jl")

projpath = Base.active_project()
hash_name = string(Base._crc32c(projpath), base = 62, pad = 6)
adir = joinpath(DEPOT_PATH[1], "asysimg", "$VERSION", hash_name)

if isdir(adir)
    files = readdir(adir, join = true)
    sysimages = filter(x -> endswith(x, ".so"), files) |> sort
    image =  isempty(sysimages) ? nothing : sysimages[end]
    println((isnothing(image) ? "" : " -J $image") * " -L $startfile")
else
    println(" -L $startfile")
end
exit()