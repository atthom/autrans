using Optim
using Chain 

function fitness(schedule, verbose=false)
    per_worker = sum(schedule, dims=1)
    per_job = sum(schedule, dims=2)
   
    balance = maximum(per_worker) - minimum(per_worker)
    job_size = fill(2, length(per_job))
    balanced_work = (per_job .- job_size).^2
    balanced_work = sum(balanced_work)
    

    # 0 or 1 loss 
    #binary_loss = @chain schedule _ .* (_ .-1) abs.(_) sum 
    #binary_loss = sum( ifelse(!in(s, [1.0, 0.0]), 100, 0) for s in schedule)
    

    spread = @chain schedule begin
        cumsum(_, dims=1)
        _[5:5:end, :]
        diff(_, dims=1)
        _ .- fill(1, size(_))
        _ .* _
        sum
    end

    if verbose
        println("$balanced_work, $(balance^2), $spread")
    end

    return balanced_work +balance + spread #+ binary_loss
end


result = optimize(fitness, zeros(35, 8), BFGS())