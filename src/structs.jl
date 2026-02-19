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
Abstract base type for all constraints
"""
abstract type AbstractConstraint end

"""
Concrete constraint types
"""
struct TaskCoverageConstraint <: AbstractConstraint end
struct NoConsecutiveTasksConstraint <: AbstractConstraint end
struct DaysOffConstraint <: AbstractConstraint end
struct OverallEquityConstraint <: AbstractConstraint end
struct DailyEquityConstraint <: AbstractConstraint end
struct TaskDiversityConstraint <: AbstractConstraint end

"""
Constraint wrapper with HARD/SOFT designation using Val for type parameter
"""
struct Constraint{T}
    constraint::AbstractConstraint
    name::String
end

# Convenience constructors
HardConstraint(c::AbstractConstraint, name::String) = Constraint{Val{:HARD}}(c, name)
SoftConstraint(c::AbstractConstraint, name::String) = Constraint{Val{:SOFT}}(c, name)

"""
Main scheduler that coordinates workers and tasks
"""
struct AutransScheduler{S <: EquityStrategy}
    workers::Vector{AutransWorker}
    tasks::Vector{AutransTask}
    num_days::Int
    max_solve_time::Float64
    verbose::Bool
    hard_constraints::Vector{Constraint{Val{:HARD}}}
    soft_constraints::Vector{Constraint{Val{:SOFT}}}
    max_relaxation_level::Int
    
    function AutransScheduler{S}(
        workers::Vector{AutransWorker},
        tasks::Vector{AutransTask},
        num_days::Int;
        max_solve_time::Float64 = 300.0,
        verbose::Bool = true,
        hard_constraints::Vector{Constraint{Val{:HARD}}} = Constraint{Val{:HARD}}[],
        soft_constraints::Vector{Constraint{Val{:SOFT}}} = Constraint{Val{:SOFT}}[],
        max_relaxation_level::Int = 5
    ) where {S <: EquityStrategy}
        # Deduplicate constraints
        hard_constraints, soft_constraints = deduplicate_constraints(
            hard_constraints, soft_constraints)
        
        new{S}(workers, tasks, num_days, max_solve_time, verbose,
               hard_constraints, soft_constraints, max_relaxation_level)
    end
end

# Convenience constructor
AutransScheduler(workers, tasks, num_days; equity_strategy::Symbol = :proportional, kwargs...) = equity_strategy == :proportional ? AutransScheduler{ProportionalEquity}(workers, tasks, num_days; kwargs...) : AutransScheduler{AbsoluteEquity}(workers, tasks, num_days; kwargs...)
