
module SchedulerApp

using GenieFramework
using DataFrames

include("lib/Scheduler.jl")
#using Metaheuristics
#using Chain
using Combinatorics
#using DataStructures
#using StatsBase

@genietools


@app begin
    @out schedule_output::R{DataTable} = DataTable(DataFrame(Tache=[], Worker=[]))
    @out page::R{DataTablePagination} = DataTablePagination(rows_per_page=50)
    @in days::R{Int} = 7
    @in task_per_day::R{Int} = 5
    @in worker_per_task::R{Int} = 2
    @in cutoff_N_first::R{Int} = 0
    @in cutoff_N_last::R{Int} = 0
    @in workers::R{Vector{String}} = ["Cookie", "Fish", "Chronos"]

    @in options::R{Vector{String}} = []
    @in form_submit = false
    @onbutton form_submit begin
        println(cutoff_N_first[], cutoff_N_last[])
        try 
            days_off = repeat([Int[]], length(workers[]))
            v = Task("Vaiselle", worker_per_task[])
            r = Task("Repas", worker_per_task[])
            task_per_day_new = [v, r, v, r, v]
            scheduler = Scheduler(zip(workers[], days_off), task_per_day_new, days[], cutoff_N_first[], cutoff_N_last[])
            res = tabu_search(scheduler, nb_gen=100, maxTabuSize=100)
            table_time, table_day, table_type, table_workers = agg_time(scheduler, res), agg_jobs(scheduler, res), agg_type(scheduler, res), agg_workers(scheduler, res)
            println(table_workers)
            schedule_output = DataTable(table_workers)
        catch e
            error_msg = sprint(showerror, e)
            st = sprint((io,v) -> show(io, "text/plain", v), stacktrace(catch_backtrace()))
            @warn "Trouble doing things:\n$(error_msg)\n$(st)"
        end
        form_submit = false
    end
end

function generate_form()
    card(
        class="schedule_settings",
        style="padding: 15px",
        [
            card_section(h4("Settings"))
            StippleUI.form(action="/sub", method="POST", [
                numberfield("Number of days *", :days, name="days", "filled", :lazy__rules,
                    rules=" [val => val !== null && val !== '' || 'Please type the number of days',
                    val => val > 0 || 'Non negative number']"
                ),
                numberfield("Task per day *", :task_per_day, name="task_per_day", "filled", :lazy__rules,
                    rules=" [val => val !== null && val !== '' || 'Please type the number of task per day',
                    val => val > 0 || 'Non negative number']"
                ),
                numberfield("People by task *", :worker_per_task, name="worker_per_task", "filled", :lazy__rules,
                    rules=" [val => val !== null && val !== ''  || 'Please type the number of worker per task']"
                ), numberfield("Remove N first tasks", :cutoff_N_first, name="cutoff_N_first", "filled", :lazy__rules,
                    rules=" [val => val !== null && val !== '']"
                ), numberfield("Remove N last tasks", :cutoff_N_last, name="cutoff_N_last", "filled", :lazy__rules,
                    rules=" [val => val !== null && val !== '']"
                ), Stipple.select(:workers, label="People", options=:options,
                    multiple=true, clearable=false, dense=false, usechips=true,
                    newvaluemode="add-unique", useinput=true, dropdownicon="none"),
                ])
            card_section(btn("submit", type="submit", color="primary", iconright="send", @click(:form_submit)))
        ]
    )
end


function uiS()
    row(cell(
        class="st-module",
        [
            cell(
                class="header",
                align="center",
                style="margin-bottom: 40px",
                [
                    h1("Autrans")
                    h3("Cool & Simple Scheduling Tool")
                ]
            )row([
                cell(class="schedule_settings_cell", xs=12, sm=6, md=2, [
                    #generate_form()
                ])
                cell(class="Time Table", xs=12, sm=12, md=9, style="margin-left: auto; margin-top: 10px;", [
                    # h3("Time Table", align="center")
                    card(class="schedule", [
                        table(title="Time Table", :schedule_output; pagination=:page)
                    ])
                ])
            ])
        ]
    ))
end


function ui()
    [
        cell(
            class="header",
            align="center",
            style="margin-bottom: 40px",
            [
                h1("Autrans")
                h3("Cool & Simple Scheduling Tool")
            ]
        )
        row([
            cell(class="schedule_settings_cell", xs=12, sm=6, md=2, [
                generate_form()
            ])
            cell(class="Time Table", xs=12, sm=12, md=9, style="margin-left: auto; margin-top: 10px;", [
                h3("Time Table", align="center")
                card(class="schedule", [
                    table(title="Time Table", :schedule_output; pagination=:page)
                ])
            ])
        ])
    ]
end

function uiX()
    [
        p("Row: {{id}}, {{rowcontent}}")
        table(:data, var"v-on:row-click"="function(event,row) {id=row.__id;rowcontent=row}")
    ]
end


@page("/", ui)


end