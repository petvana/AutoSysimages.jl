module Snooping

snoop_file = nothing
snoop_file_io = nothing

function start_snooping()
    global snoop_file_io
    if snoop_file_io === nothing
        global snoop_file = "$(tempname())-snoop.jl"
        mkpath(dirname(snoop_file))
        global snoop_file_io = open(snoop_file, "w")
        ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), snoop_file_io.handle)
    else
        @warn("Snooping is already running -> $(snoop_file)")
    end
end

function stop_snooping()
    if isnothing(snoop_file_io)
        @warn("No active snooping file")
        return 
    end
    ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), C_NULL)
    close(snoop_file_io)
    global snoop_file_io = nothing
    statements = retrieve_stetements()
    isfile(snoop_file) && rm(snoop_file)
    return statements
end

flush_statements() = (isnothing(snoop_file_io) || flush(snoop_file_io); nothing)

function retrieve_stetements()
    flush_statements()
    lines = readlines(snoop_file)
    precompiles = String[]
    for line in lines
        sp = split(line, "\t")
        length(sp) == 2 && push!(precompiles, sp[2][2:end-1])
    end
    return precompiles
end

end