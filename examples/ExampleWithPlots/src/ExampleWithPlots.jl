module ExampleWithPlots

using Plots

function run()
    x = 1:10; y = rand(10); # These are the plotting data
    plot(x, y)
end

end # module
