using Pkg

# This provides a simplified implementation of `pkgversion()`
# See https://github.com/JuliaLang/julia/blob/b1f8d16833f161158119d4a2e250a36a4f7f6482/base/loading.jl#L475-L503
if VERSION < v"1.9.0"
    if VERSION < v"1.7.0"
        function pkgdir(m::Module, paths::String...)
            rootmodule = Base.moduleroot(m)
            path = pathof(rootmodule)
            path === nothing && return nothing
            return joinpath(dirname(dirname(path)), paths...)
        end
    end

    function locate_project_file(env::String)
        project_file = joinpath(env, "Project.toml")
        if Base.isfile_casesensitive(project_file)
            return project_file
        end
        return true
    end

    function get_pkgversion_from_path(path)
        project_file = locate_project_file(path)
        if project_file isa String
            d = Pkg.TOML.parsefile(project_file)
            v = get(d, "version", nothing)
            v !== nothing && return VersionNumber(v::String)
        end
        return nothing
    end

    function pkgversion(m::Module)
        path = pkgdir(m)
        path === nothing && return nothing
        return get_pkgversion_from_path(path)
    end
end
