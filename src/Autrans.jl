module Autrans

using Stipple, StippleUI
using DataFrames
using Metaheuristics
using Chain
using Combinatorics
using DataStructures
using StatsBase

export SmallSchedule, fitness, optimize, find_schedule, search_space, cardinality, julia_main, make_df

include("structures.jl")
include("core.jl")

#include("autrans_ui.jl")


if abspath(PROGRAM_FILE) == @__FILE__
    julia_main()
end


end