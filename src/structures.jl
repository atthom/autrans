

@enum TypeTask begin
    cuisine
    vaiselle
 end
 
@enum TypeTime begin
    matin
    midi
    soir
end

struct SmallSchedule
    days::Int
    task_per_day::Int
    worker_per_work::Int
    workers::Vector{String}
    nb_workers::Int
end

struct SmallTask
    worker_per_task::Int
    per_day::Int
end

struct SmallWorker
    name::String
    preference_task::Vector{SmallTask}
    preference_worker::Vector{SmallWorker}
end


SmallSchedule(days::Int, task_per_day::Int, worker_per_work::Int, workers::Vector{String}) = SmallSchedule(days, task_per_day, worker_per_work, workers, length(workers))


Searchpath(s::SmallSchedule) = BitArraySpace(s.days*s.task_per_day*s.nb_workers)
Base.reshape(result, s::SmallSchedule) = reshape(result, (s.days*s.task_per_day, s.nb_workers))