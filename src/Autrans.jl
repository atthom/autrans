module Autrans

using Stipple, StippleUI
using DataFrames
using Metaheuristics
using Distributions: maximum
using Chain



include("structures.jl")
include("core.jl")

include("autrans_ui.jl")

end