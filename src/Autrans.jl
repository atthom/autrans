module Autrans

using Stipple, StippleUI
using DataFrames
using Metaheuristics
using Distributions: maximum
using Chain
using PrettyTables

export SmallSchedule, fitness, pprint, optimize, make_df


include("structures.jl")
include("core.jl")

include("autrans_ui.jl")

end