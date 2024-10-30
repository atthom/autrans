import streamlit as st
from streamlit_tags import st_tags, st_tags_sidebar
import pandas as pd
import numpy as np
import requests




@st.dialog("Schedule is not possible")
def sat_schedule(txt):
    st.markdown(f"<h3 style='text-align: center'>{txt}</h3>", unsafe_allow_html=True)
    if st.button("OK"):
        st.rerun()

def set_df(layout, payload, cols=[]):
    data = np.array(payload["columns"]).T
    df = pd.DataFrame(data, columns=payload["colindex"]["names"])
    if cols != []:
        df.columns = cols
    layout = layout.dataframe(df, use_container_width=True, hide_index=True)


def make_table(title, cols):
    row1 = st.columns([10])
    row1[0].markdown(f"<h3 style='text-align: center;'>{title}</h3>", unsafe_allow_html=True)

    row2 = st.columns([10])
    return row2[0].dataframe(pd.DataFrame(columns=cols), hide_index=True, use_container_width=True)

st.set_page_config(page_title="Autrans", page_icon="🧊", layout="wide")

if False:
    st.markdown("""
        <style>
            .reportview-container {
                margin-top: -2em;
            }
            #MainMenu {visibility: hidden;}
            .stDeployButton {display:none;}
            footer {visibility: hidden;}
            #stDecoration {display:none;}
        </style>
    """, unsafe_allow_html=True)

st.markdown("<h1 style='text-align: center;'>Autrans</h1>", unsafe_allow_html=True)
st.markdown("<h2 style='text-align: center;'>Automated Scheduling Tool</h2>", unsafe_allow_html=True)


st.markdown("")
st.markdown("")
st.markdown("")


settings, tables = st.columns([4, 8])

weekdays = ["Monday", "Tuesday" , "Wednesday", "Thursday" , "Friday", "Saturday", "Sunday"]
with settings.container(border=True):
    header = st.columns([6])
    header[0].header("Settings")
    st.divider()

    settings_row1 = st.columns([2, 3, 3])
    nb_days = settings_row1[0].number_input("Number of days", value=7, help="Number of days for the planning", max_value=20)
    weekday_display = settings_row1[1].toggle("Days of the week", value=False, help="Display planning with days of the week")
    if weekday_display:
        start_with = settings_row1[2].selectbox("Start with", placeholder="Monday", 
                                                options=weekdays, help="Start planning with a specific day")
        startday = weekdays.index(start_with)
        selected_days = [(weekdays[(startday+i)%7], (startday+i) // 7) for i in range(nb_days)]
        multiple_week = any(i>=1 for w, i in selected_days)

        if multiple_week:
            selected_days = [d + f" (w {1+i})" for d, i in selected_days]
        else:
            selected_days = [d for d, i in selected_days]
        
    else:
        selected_days = [f"Day {i+1}" for i in range(nb_days)]

    st.divider()

    task_row = st.columns([6]) 
    task_row[0].header("Tasks")

    task_row1 = st.columns([2, 2, 2])
    number_of_tasks = task_row1[0].number_input("Number of tasks", value=3, key="number_of_tasks", min_value=1, max_value=10,
                                                help="Number of different type of task in the Schedule")
    cutoff_first = task_row1[1].number_input("Delete firsts tasks", value=1, min_value=0,
                                             help="Remove the firsts tasks at the beginning of the Schedule")
    cutoff_last = task_row1[2].number_input("Delete last tasks", value=2, min_value=0,
                                            help="Remove the lasts tasks at the end of the Schedule")

    task_blank = st.columns([6])
    all_tasks = []
    for i in range(number_of_tasks):
        task_row_i = st.columns([3, 3])
        task_name_i = task_row_i[0].text_input(f"Task name", value=f"Task {i+1}", key=f"task_name_{i}",
                                               help="Name of the task")
        nb_worker_i = task_row_i[1].number_input("People required", value=2, key=f"task_workers_{i}",
                                               help="Number of people needed to complete the task")
        all_tasks.append((task_name_i, nb_worker_i, 1))

    task_per_day, _, _ = zip(*all_tasks)

    st.divider()

    worker_row = st.columns([6])
    worker_row[0].header("Workers")

    worker_row1 = st.columns([2, 2, 2], vertical_alignment="center")
    nb_workers = worker_row1[0].number_input("Number of people", value=4, max_value=20,
                                            help="Total number of people that will perform tasks")
    with_days_off = worker_row1[1].toggle("Add days off", value=False,
                                          help="Include holidays")
    
    if with_days_off:
        balance_daysoff = worker_row1[2].toggle("Balance days off", value=False, 
                                            help="""If true, workers will work in proportion of theirs working days.
                                                If false, worker in vacation will catch up on their vacation days.""")
    else:
        balance_daysoff = False

    all_workers = []
    for i in range(nb_workers):
        worker_row1 = st.columns([2, 4])
        worker_name = worker_row1[0].text_input(f"Name", value=f"Person {i+1}", key=f"worker_name_{i}")

        if with_days_off:
            worker_days_off = worker_row1[1].multiselect("Days off", options=selected_days, default=[], key=f"worker_days_off_{i}",
                                                         help="Select on which days this person will not be working")
        else:
            worker_days_off = []

        all_workers.append((worker_name, [selected_days.index(d) for d in worker_days_off]))
    
    workers, _ = zip(*all_workers)
    workers = list(workers)

    st.divider()

    row5 = st.columns([2, 2, 2])
    submit = row5[1].button("Submit", type="primary")

 
with tables:
    schedule_display = make_table("Schedule", ["Tasks"] + selected_days)
    task_agg = make_table("Affectation per day", ["Days"] + workers)
    task_per_day_agg = make_table("Affectation per task", ["Tasks"] + workers)


    

if submit:
    
    payload = {
        "workers": all_workers,
        "tasks": all_tasks,
        "nb_days": nb_days,
        "task_per_day": task_per_day,
        "cutoff_first": cutoff_first,
        "cutoff_last": cutoff_last,
        "balance_daysoff": balance_daysoff
    }
    print(payload)
    import time

    t = time.time()
    res1 = requests.post("http://127.0.0.1:8080/sat", json=payload)
    sat_agg = res1.json()

    t_sat = round(time.time() - t, 2)

    if sat_agg["sat"]:
        res = requests.post("http://127.0.0.1:8080/schedule", json=payload)
        all_agg = res.json()
        
        t_schedule = round(time.time() - t, 2)

        for layout, agg in zip([schedule_display, task_agg, task_per_day_agg], ["display", "time", "jobs"]):
            if agg == "display":
                set_df(layout, all_agg[agg], ["Tasks"] + selected_days)
            else:
                set_df(layout, all_agg[agg])
    else:
        sat_schedule(sat_agg["msg"])
        
        