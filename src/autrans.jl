module Autrans

using Stipple, StippleUI
using DataFrames
using Metaheuristics
using Distributions: maximum
using Chain
using Combinatorics
using PrettyTables
using Combinatorics

export SmallSchedule, fitness, optimize, find_schedule, search_space, cardinality


include("structures.jl")
include("core.jl")

include("autrans_ui.jl")

end