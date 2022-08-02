using Documenter, AutoSysimages

makedocs(
    sitename="AutoSysimages.jl",
    modules = [AutoSysimages],
)

deploydocs(
    repo = "github.com/petvana/AutoSysimages.jl.git"
)