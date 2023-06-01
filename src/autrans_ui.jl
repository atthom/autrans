

@vars ViewSchedule begin
  days::R{Int} = 7
  task_per_day::R{Int} = 2
  worker_per_task::R{Int} = 2
  workers::R{Vector{String}} = ["Cookie", "Fish", "Chronos"]
  options::R{Vector{String}} = []
end


@vars OLD begin
  process = false
  input = ""
  # you can explicitly define the type of the variable
  output::String = "", READONLY
  days::int
  task_per_day::int
  worker_per_task::int

  #options::Vector{String} = ["Cookie", "Fish", "Chronos"]
  #workers::R{Vector{String}} = []
  #options::R{Vector{String}} = ["Cookie", "Fish", "Chronos"]
end

function handlers(model)
  println(model)

  model
end

function generate_form()

    row(cell(class="schedule_settings_cell", size=2, md=3, sm=12, [
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
    
            select(:workers, label="Workers", options=:options,
                     multiple=true, clearable = false, 
                    dense=false, dropdownicon="none",
                    newvaluemode="add-unique", useinput=true,
                   usechips = true),
            ])
            card_section(btn("submit", type = "submit", color = "primary", iconright = "send"))
        ])
    
    
        cell(class="Schedule table", size=6, md=6, sm=12, [
          p("here")
    
        ])
      ])
      
      )
end

function ui()
  row(cell(class = "st-module", [
    cell(class="header", align="center",  [
      h1("Autrans")
      h3("Small Scheduling Tool")
    ])
    generate_form()
  ]))
end

route("/") do
  model = ViewSchedule |> init |> handlers
  page(model, class = "container", ui(), title = "Autrans") |> Stipple.html
end

Genie.isrunning(:webserver) || up()