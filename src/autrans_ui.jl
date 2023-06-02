

@vars ViewSchedule begin
  days::R{Int} = 7
  task_per_day::R{Int} = 5
  worker_per_task::R{Int} = 2
  workers::R{Vector{String}} = ["Cookie", "Fish", "Chronos"]
  options::R{Vector{String}} = []
  form_submit::R{Bool} = false
  schedule_output::R{String} = "Schedule is here"
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
        #@info model
        schedule = SmallSchedule(model.days[], model.task_per_day[], model.worker_per_task[], model.workers[])
        @info schedule
        result = optimize(x -> fitness(x, schedule), schedule)
        @info fitness(result, schedule, true)
        model.schedule_output[] = pprint(schedule, result)

        model.form_submit = false
    end

    model
end

function generate_form()
    card(class = "schedule_settings", size=2, md=3, sm=12, [
        card_section(p("Schedule Settings"))
        
        StippleUI.form(action = "/sub", method = "POST", [
  
          numberfield("Days *", :days, name = "days", "filled", :lazy__rules,
            rules = " [val => val !== null && val !== '' || 'Please type the number of days',
              val => val > 0 || 'Non negative number']"
          ),
          numberfield("Task per day *", :task_per_day, name = "task_per_day", "filled", :lazy__rules,
            rules = " [val => val !== null && val !== '' || 'Please type the number of task per day',
              val => val > 0 || 'Non negative number']"
          ),
          numberfield("Worker per task *", :worker_per_task, name = "worker_per_task", "filled", :lazy__rules,
            rules = " [val => val !== null && val !== ''  || 'Please type the number of worker per task']"
          ),
  
          Stipple.select(:workers, label="Workers", options=:options,
                   multiple=true, clearable = false, 
                  dense=false, dropdownicon="none",
                  newvaluemode="add-unique", useinput=true,
                 usechips = true),
          ])
          card_section(btn("submit", type = "submit", color = "primary", iconright = "send", @click(:form_submit)))
      ])
end

function ui()
  row(cell(class = "st-module", [
    cell(class="header", align="center",  [
      h1("Autrans")
      h3("Small Scheduling Tool")
    ])
    
    row(cell(class="schedule_settings_cell", size=2, md=3, sm=12, [
        generate_form()
    
        cell(class="Schedule table", size=6, md=6, sm=12, [
            card(class = "q-my-md", [
                #card_section("{{ schedule_output }}")
                #render(parse_vue_html("{{schedule_output}}"))
            ])
        ])
      ])
      
      )

      @text(:schedule_output)
  ]))
end

route("/") do
  model = ViewSchedule |> init |> handlers
  page(model, class = "container", ui(), title = "Autrans") |> Stipple.html
end

Genie.isrunning(:webserver) || up()