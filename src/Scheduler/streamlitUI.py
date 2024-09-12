import streamlit as st
from streamlit_tags import st_tags, st_tags_sidebar
import pandas as pd
import numpy as np
import requests


    


def set_df(layout, payload, cols=[]):
    #payload ={"columns": [["Vaiselle", "Repas", "Vaiselle", "Repas", "Vaiselle"], [1, 1, 1, 2, 1], [1, 2, 1, 2, 1], [1, 2, 1, 1, 1], [1, 2, 1, 2, 2], [1, 2, 1, 2, 1], [1, 2, 2, 2, 1], [1, 2, 2, 2, 1], [1, 2, 1, 2, 1], [1, 1, 1, 2, 1], [1, 2, 2, 1, 1], [1, 1, 1, 2, 1]], "colindex": {"lookup": {"Curt": 10, "Bizard": 12, "Jon": 4, "Mayel": 7, "Fishy": 3, "Alicia": 9, "Poulpy": 5, "Chronos": 2, "Melanight": 11, "Tasks": 1, "LeRat": 6, "Bendo": 8}, "names": ["Tasks", "Chronos", "Fishy", "Jon", "Poulpy", "LeRat", "Mayel", "Bendo", "Alicia", "Curt", "Melanight", "Bizard"]}, "metadata": None, "colmetadata": None, "allnotemetadata": True}
    data = np.array(payload["columns"]).T
    df = pd.DataFrame(data, columns=payload["colindex"]["names"])
    if cols != []:
        df.columns = cols
    layout = layout.dataframe(df, use_container_width=True)

st.set_page_config(page_title="Autrans", page_icon="🧊", layout="wide")


header1, header2, header3 = st.columns([4, 4, 4])
header2.title("Autrans")
header2.subheader("Automated Planning Tool")

settings, tables = st.columns([4, 8])

weekdays = ["Monday", "Tuesday" , "Wednesday", "Thursday" , "Friday", "Saturday", "Sunday"]
with settings.container(border=True):
    header = st.columns([6])
    header[0].title("Schedule Settings")
    st.divider()

    settings_row1 = st.columns([2, 2, 2])
    nb_days = settings_row1[0].number_input("Number of days", value=7)
    weekday_display = settings_row1[1].toggle("Weekday display", value=False)
    if weekday_display:
        start_with = settings_row1[2].selectbox("Start with", placeholder="Monday", options=weekdays)

    if weekday_display:
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
    task_row[0].title("Tasks")

    task_row1 = st.columns([2, 2, 2])
    number_of_tasks = task_row1[0].number_input("Number of tasks", value=1, key="number_of_tasks", min_value=1, max_value=10)
    cutoff_first = task_row1[1].number_input("Delete first tasks", value=1, min_value=0)
    cutoff_last = task_row1[2].number_input("Delete last tasks", value=2, min_value=0)

    all_tasks = []
    for i in range(number_of_tasks):
        task_row_i = st.columns([2, 2, 2])
        task_name_i = task_row_i[0].text_input(f"Task name", value=f"Task {i+1}", key=f"task_name_{i}")
        nb_worker_i = task_row_i[1].number_input("Number of workers", value=2, key=f"task_workers_{i}")
        task_difficulty_i = task_row_i[2].number_input("Task difficulty", value=1, key=f"task_difficulty_{i}")
        all_tasks.append((task_name_i, nb_worker_i, task_difficulty_i))

    task_row4 = st.columns([6])
    all_task_names, _, _ = zip(*all_tasks)

    task_per_day = st_tags(
            label="Ordres des Tâches pour une journée type:",
            text="add more",
            value=[all_task_names[0], all_task_names[-1], all_task_names[0]],
            suggestions=all_task_names,
            maxtags = 15,
            key="task_per_day")
    task_row4[0] = task_per_day
    st.divider()

    worker_row = st.columns([6])
    worker_row[0].title("Workers")

    worker_row1 = st.columns([2, 2, 2], vertical_alignment="center")
    nb_workers = worker_row1[0].number_input("Number of workers", value=7)
    with_days_off = worker_row1[1].toggle("Add holidays", value=False)
    balance_daysoff = worker_row1[2].toggle("Rebalance holidays", value=False)

    all_workers = []
    for i in range(nb_workers):
        worker_row1 = st.columns([2, 4])
        worker_name = worker_row1[0].text_input(f"Worker name", value=f"Worker {i+1}", key=f"worker_name_{i}")

        if with_days_off:
            worker_days_off = worker_row1[1].multiselect("Holidays", options=selected_days, default=[], key=f"worker_days_off_{i}")
        else:
            worker_days_off = []

        all_workers.append((worker_name, worker_days_off))
    
    workers, _ = zip(*all_workers)
    workers = list(workers)

    st.divider()

    row5 = st.columns([2, 2, 2])
    submit = row5[1].button("Submit", type="primary")

 
with tables:
    row1 = st.columns([10])
    row1[0].header("Planning")
    row2 = st.columns([10])
    schedule_display = row2[0].dataframe(pd.DataFrame(columns=["Tasks"] + selected_days),
                                         hide_index=True, use_container_width=True)

    row5 = st.columns([10])
    row5[0].header("Répartition par jour")
    row6 = st.columns([10])
    task_agg = row6[0].dataframe(pd.DataFrame(columns=["Days"] + workers),  hide_index=True, use_container_width=True)

    row3 = st.columns([10])
    row3[0].header("Répartition par tâche")
    row4 = st.columns([10])
    time_agg = row4[0].dataframe(pd.DataFrame(columns=["Tasks"] + workers), hide_index=True, use_container_width=True)

    row7 = st.columns([10])
    row7[0].header("Répartition par tâche dans la journée")
    row8 = st.columns([10])
    task_per_day_agg = row8[0].dataframe(pd.DataFrame(columns=["Tasks"] + workers),  hide_index=True, use_container_width=True)


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

    res = requests.post("http://localhost:8080/schedule", json=payload)
    all_agg = res.json()

    print(all_agg["display"])
    print(all_agg["type"])
    print(all_agg["time"])
    print(all_agg["jobs"])

    for layout, agg in zip([schedule_display, time_agg, task_agg, task_per_day_agg], ["display", "type", "time", "jobs"]):
        if agg == "display":
            set_df(layout, all_agg[agg], ["Tasks"] + selected_days)
        else:
            set_df(layout, all_agg[agg])

