"""
Represents a worker with their availability constraints
"""
struct AutransWorker
    name::String
    days_off::Set{Int}
    
    AutransWorker(name::String, days_off::Set{Int} = Set{Int}()) = new(name, days_off)
    AutransWorker(name::String, days_off::Vector{Int}) = new(name, Set(days_off))
end

"""
Represents a task with its requirements
"""
struct AutransTask
    name::String
    num_workers::Int
    day_range::UnitRange{Int}
    
    AutransTask(name::String, num_workers::Int, day_range::UnitRange{Int}) = new(name, num_workers, day_range)
    AutransTask(name::String, num_workers::Int, day_in::Int, day_out::Int) = new(name, num_workers, UnitRange(day_in, day_out))
    AutransTask(name::String, num_workers::Int, day_in::Int) = new(name, num_workers, UnitRange(day_in, day_in))
end

"""
Equity strategy types for compile-time dispatch
"""
abstract type EquityStrategy end
struct ProportionalEquity <: EquityStrategy end
struct AbsoluteEquity <: EquityStrategy end

"""
Main scheduler that coordinates workers and tasks
"""
struct AutransScheduler{S <: EquityStrategy}
    workers::Vector{AutransWorker}
    tasks::Vector{AutransTask}
    num_days::Int
    max_solve_time::Float64
    verbose::Bool
    
    function AutransScheduler{S}(
        workers::Vector{AutransWorker},
        tasks::Vector{AutransTask},
        num_days::Int;
        max_solve_time::Float64 = 300.0,
        verbose::Bool = true
    ) where {S <: EquityStrategy}
        new{S}(workers, tasks, num_days, max_solve_time, verbose)
    end
end

# Convenience constructor
AutransScheduler(workers, tasks, num_days; equity_strategy::Symbol = :proportional, kwargs...) = equity_strategy == :proportional ? AutransScheduler{ProportionalEquity}(workers, tasks, num_days; kwargs...) : AutransScheduler{AbsoluteEquity}(workers, tasks, num_days; kwargs...)
