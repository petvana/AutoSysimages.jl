using Documenter, AutoSysimages

makedocs(
    sitename="AutoSysimages.jl",
    modules = [AutoSysimages],
    pages = [
        "index.md",
        "install.md",
        "chained.md",
        "api.md",
    ]
)

deploydocs(
    repo = "github.com/petvana/AutoSysimages.jl.git"
)