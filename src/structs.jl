"""
Represents a worker with their availability constraints
"""
struct AutransWorker
    name::String
    days_off::Set{Int}
    task_preferences::Vector{Int}  # Ranked list of task indices (1-based, empty = no preference)
    workload_offset::Int  # Adjustment to workload: negative = work less, positive = work more, 0 = no adjustment
    
    # Full constructor
    AutransWorker(name::String, days_off::Set{Int}, task_preferences::Vector{Int}, workload_offset::Int) = new(name, days_off, task_preferences, workload_offset)
    
    # Backward-compatible constructors (default workload_offset to 0)
    AutransWorker(name::String, days_off::Set{Int} = Set{Int}(), task_preferences::Vector{Int} = Int[]) = new(name, days_off, task_preferences, 0)
    AutransWorker(name::String, days_off::Vector{Int}, task_preferences::Vector{Int} = Int[]) = new(name, Set(days_off), task_preferences, 0)
    AutransWorker(name::String, days_off::Vector{Int}, task_preferences::Vector{Int}, workload_offset::Int) = new(name, Set(days_off), task_preferences, workload_offset)
end

"""
Represents a task with its requirements
"""
struct AutransTask
    name::String
    num_workers::Int
    day_range::UnitRange{Int}
    difficulty::Int  # Task difficulty (default 1, must be >= 1)
    
    # Full constructor with difficulty
    function AutransTask(name::String, num_workers::Int, day_range::UnitRange{Int}, difficulty::Int)
        @assert difficulty >= 1 "Task difficulty must be at least 1"
        new(name, num_workers, day_range, difficulty)
    end
    
    # Backward-compatible constructors (default difficulty to 1)
    AutransTask(name::String, num_workers::Int, day_range::UnitRange{Int}) = AutransTask(name, num_workers, day_range, 1)
    AutransTask(name::String, num_workers::Int, day_in::Int, day_out::Int) = AutransTask(name, num_workers, UnitRange(day_in, day_out), 1)
    AutransTask(name::String, num_workers::Int, day_in::Int) = AutransTask(name, num_workers, UnitRange(day_in, day_in), 1)
    AutransTask(name::String, num_workers::Int, day_in::Int, day_out::Int, difficulty::Int) = AutransTask(name, num_workers, UnitRange(day_in, day_out), difficulty)
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
struct WorkerPreferenceConstraint <: AbstractConstraint end
struct OneTaskPerDayConstraint <: AbstractConstraint end

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
