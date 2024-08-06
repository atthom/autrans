# Copyright 2024 Thomas
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

using Dash
using JSON
using OrderedCollections, DataFrames   


data = OrderedDict(
      "Date" => ["2015-01-01", "2015-10-24", "2016-05-10", "2017-01-10", "2018-05-10", "2018-08-15"],
      "Region" => ["Montreal", "Toronto", "New York City", "Miami", "San Francisco", "London"],
      "Temperature" => [1, -20, 3.512, 4, 10423, -441.2],
      "Humidity" => [10, 20, 30, 40, 50, 60],
      "Pressure" => [2, 10924, 3912, -10, 3591.2, 15],
)

df = DataFrame(data) 

app = dash(external_stylesheets=["https://codepen.io/chriddyp/pen/bWLwgP.css"])

app.layout = html_div() do
    html_h1(html_center("Autrans")),
    html_h2(html_center("Planning Automated Tool")),
    html_div([
        html_form([
            html_h4("Settings"),
            html_div([
                "Workers: ",
                html_textarea(
                    """[\"Chronos\",[]],
                [\"Jon\",[]],
                        [\"Beurre\",[]],
                        [\"Fishy\",[]],
                        [\"Bendo\",[]],
                        [\"Alicia\",[]],
                        [\"Poulpy\",[]],
                        [\"Curt\",[]],
                        [\"LeRat\",[]],
                        [\"Bizard\",[]]""",
                    cols=30, rows=15)
            ]),
            html_div([
                "Tasks: ",
                dcc_input(
                    value="""[[\"Vaiselle\",2,1],[\"Repas\",3,1]]""",
                    id="tasks", type="text")
            ]),
            html_div([
                "Task per day: ",
                dcc_input(
                    value="[0, 1, 0, 1, 0]",
                    id="tasks_per_day", type="text")
            ]),
            html_div([
                "Number of days: ",
                dcc_input(id="days", value=7, type="Number")
            ]),

            html_div([
                "Cutoff N first tasks: ",
                dcc_input(id="N_first", value=1, type="Number")
            ]),
            html_div([
                "Cutoff N last tasks: ",
                dcc_input(id="N_last", value=2, type="Number")
            ]),
            
            html_button("Submit", id="btn-submit")
        ])
    ])

    
    html_div(
        html_center([
            dash_datatable(
                data = map(eachrow(df)) do r Dict(names(r) .=> values(r)) end,
                columns=[Dict("name" =>c, "id" => c) for c in names(df)])
        ])
    )
end


callback!(app, Output("my-div", "children"), Input("my-id", "value")) do input_value
    "You've entered $(input_value)"
end


run_server(app)