using Metaheuristics

using Statistics



contrearg(v::Vector{Float64}) = ifelse(mean(v) < (median(v) / 2), 0, 100)



bounds = boxconstraints(lb = 0*ones(100), ub = 10ones(100))

#options = Options(f_calls_limit = 90000*10, f_tol = 1e-5, seed=1)
#algorithm = ECA(information = Information(f_optimum = 0.0), options = options)


result = optimize(contrearg, bounds, GA(N=10000, mutation=SlightMutation()))


dataset = rand(0:100, (1_000_000, 10))

for i in 1:100000
    d = dataset[i, :]
    if contrearg(d)
        println(d)
    end
end