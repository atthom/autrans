
@vars ViewSchedule begin
  days::R{Int} = 7
  task_per_day::R{Int} = 5
  worker_per_task::R{Int} = 2
  cutoff_N_first::R{Int} = 0
  cutoff_N_last::R{Int} = 0
  workers::R{Vector{String}} = ["Cookie", "Fish", "Chronos"]
  options::R{Vector{String}} = []
  form_submit::R{Bool} = false
  schedule_output::R{DataTable} = DataTable(DataFrame(Tache=[], Worker=[]))
  page::R{DataTablePagination} = DataTablePagination(rows_per_page=50)
end

function handlers(model)
    on(model.isready) do isready
        isready || return
        @async begin
            sleep(0.2)
            push!(model)
        end
    end

    onbutton(model.form_submit) do
        df = find_schedule(model.days[], model.task_per_day[], 
                          model.worker_per_task[], model.workers[], 
                          model.cutoff_N_first[], model.cutoff_N_last[])
        model.schedule_output[] = DataTable(df)
        model.form_submit[] = false
    end

    model
end

function generate_form()
  card(class = "schedule_settings", style="padding: 15px", [
    card_section(h4("Settings"))
    
    StippleUI.form(action = "/sub", method = "POST", [
      numberfield("Number of days *", :days, name = "days", "filled", :lazy__rules,
        rules = " [val => val !== null && val !== '' || 'Please type the number of days',
          val => val > 0 || 'Non negative number']"
      ),
      numberfield("Task per day *", :task_per_day, name = "task_per_day", "filled", :lazy__rules,
        rules = " [val => val !== null && val !== '' || 'Please type the number of task per day',
          val => val > 0 || 'Non negative number']"
      ),
      numberfield("People by task *", :worker_per_task, name = "worker_per_task", "filled", :lazy__rules,
        rules = " [val => val !== null && val !== ''  || 'Please type the number of worker per task']"
      ),

      numberfield("Remove N first tasks", :cutoff_N_first, name = "cutoff_N_first", "filled", :lazy__rules,
        rules = " [val => val !== null && val !== '']"
      ),

      numberfield("Remove N last tasks", :cutoff_N_last, name = "cutoff_N_last", "filled", :lazy__rules,
        rules = " [val => val !== null && val !== '']"
      ),

      Stipple.select(:workers, label="People", options=:options,
        multiple=true, clearable = false, dense=false, usechips = true,
        newvaluemode="add-unique", useinput=true, dropdownicon="none"),

    ])
    card_section(btn("submit", type = "submit", color = "primary", iconright = "send", @click(:form_submit)))
  ])
end

function ui()
  row(cell(class = "st-module", [
    cell(class="header", align="center", style="margin-bottom: 40px", [
      h1("Autrans")
      h3("Cool & Simple Scheduling Tool")
    ])
    
    row([
      cell(class="schedule_settings_cell", xs=12, sm=6, md=2, [
        generate_form()
      ])
      cell(class="Time Table", xs=12, sm=12, md=9, style="margin-left: auto; margin-top: 10px;", [
        # h3("Time Table", align="center")
        card(class = "schedule", [
        table(title="Time Table", :schedule_output; pagination=:page)
        ])
      ])
    ])
  ]))
end

Genie.config.run_as_server = true


function main(port, host)::Cint  
  
  route("/") do
    model = ViewSchedule |> init |> handlers
    page(model, class = "container", ui(), title = "Autrans") |> html
  end

  up(port, host, async = false)
end

Base.@ccallable function julia_main()::Cint  
  host = ARGS[1]
  port = parse(Int, ARGS[2])
  main(port, host)

  return 0
end
# create_sysimage(["Autrans"], sysimage_path="Autrans.so")
# julia --color=yes --depwarn=no --project=@. -q -L bootstrap.jl -J YourProjectName.so – “$@”

