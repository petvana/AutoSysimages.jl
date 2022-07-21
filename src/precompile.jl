for (_pkgid, _mod) in Base.loaded_modules
    if !(_pkgid.name in ("Main", "Core", "Base"))
        Base.eval(PrecompileStagingArea, :(const $(Symbol(_mod)) = $_mod))
    end
end

let 
    status_true = status_false = status_fail = 0
    statement_file = "statements.txt"
    if isfile(statement_file)
        for statement in eachline(statement_file)
            # println(statement)
            # The compiler has problem caching signatures with `Vararg{?, N}`. Replacing
            # N with a large number seems to work around it.
            statement = replace(statement, r"Vararg{(.*?), N} where N" => s"Vararg{\\1, 100}")
            statement = "precompile($statement)"
            try
                Base.include_string(PrecompileStagingArea, "tmp = " * statement)
                if PrecompileStagingArea.tmp
                    #printstyled("\r", statement, "\n", color = :green)
                    status_true += 1
                else
                    printstyled("\r", statement, "\n", color = :yellow)
                    status_false += 1
                end
            catch
                printstyled("\r", statement, "\n", color = :red)
                status_fail += 1
                # See julia issue #28808
                @debug "failed to execute \$statement"
            end
            print("\r Compilation (")
            printstyled(status_true, color = status_true > 0 ? :green : :normal )
            print(",")
            printstyled(status_false, color = status_false > 0 ? :yellow : :normal )
            print(",")
            printstyled(status_fail, color = status_fail > 0 ? :red : :normal )
            print(")     ")
        end
    else
        @warn "There is no statement file"
    end
end
println()