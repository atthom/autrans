import streamlit as st
from streamlit_tags import st_tags, st_tags_sidebar
import pandas as pd
import numpy as np
import requests


def set_df(layout, payload):
    #payload ={"columns": [["Vaiselle", "Repas", "Vaiselle", "Repas", "Vaiselle"], [1, 1, 1, 2, 1], [1, 2, 1, 2, 1], [1, 2, 1, 1, 1], [1, 2, 1, 2, 2], [1, 2, 1, 2, 1], [1, 2, 2, 2, 1], [1, 2, 2, 2, 1], [1, 2, 1, 2, 1], [1, 1, 1, 2, 1], [1, 2, 2, 1, 1], [1, 1, 1, 2, 1]], "colindex": {"lookup": {"Curt": 10, "Bizard": 12, "Jon": 4, "Mayel": 7, "Fishy": 3, "Alicia": 9, "Poulpy": 5, "Chronos": 2, "Melanight": 11, "Tasks": 1, "LeRat": 6, "Bendo": 8}, "names": ["Tasks", "Chronos", "Fishy", "Jon", "Poulpy", "LeRat", "Mayel", "Bendo", "Alicia", "Curt", "Melanight", "Bizard"]}, "metadata": None, "colmetadata": None, "allnotemetadata": True}
    data = np.array(payload["columns"]).T
    df = pd.DataFrame(data, columns=payload["colindex"]["names"])
    layout = layout.dataframe(df, use_container_width=True)

st.set_page_config(page_title="Autrans", page_icon="🧊", layout="wide")


header1, header2, header3 = st.columns([4, 4, 4])
header2.title("Autrans")
header2.subheader("Automated Planning Tool")

settings, tables = st.columns([4, 8])

with settings.form("settings"):
    header = st.columns([6])
    header[0].header("Paramètres")

    row1 = st.columns([2, 2, 2])
    nb_days = row1[0].number_input("Nombre de Jours", value=7)
    cutoff_first = row1[1].number_input("Del N premières tâches", value=1)
    cutoff_last = row1[2].number_input("Del N dernières tâches", value=2)

    row2 = st.columns([3, 3])
    task_name1 = row2[0].text_input("Tâche 1", value="Vaiselle")
    nb_worker1 = row2[1].number_input("Combien de personnes", value=2, key="nb_worker_vaiselle")

    row22 = st.columns([3, 3])
    task_name2 = row22[0].text_input("Tâche 2", value="Repas")
    nb_worker2 = row22[1].number_input("Combien de personnes", value=3, key="nb_worker_repas")

    row3 = st.columns([3, 3])

    workers = st_tags(
            label="Qui?",
            text="add more",
            value=["Chronos", "Jon", "Beurre", "Poulpy", "LeRat", "Alichat", "Bendo", "Curt", "Fishy", "Melanight", "Bizzard", "Arc", "Zozo"],
            suggestions=["Chronos", "Jon", "Beurre", "Poulpy", "LeRat", "Alichat", "Bendo", "Curt", "Fishy", "Melanight", "Bizzard", "Arc", "Zozo"],
            maxtags = 20,
            key="worker")
    row3[0] = workers

    task_per_day = st_tags(
            label="Ordres des Tâches pour une journée type:",
            text="add more",
            value=["Vaisselle", "Repas", "Vaisselle", "Repas", "Vaisselle"],
            suggestions=[""],
            maxtags = 15,
            key="task_per_day")
    row3[1] = task_per_day

    row4 = st.columns([6])
    row4[0].header("Jours travaillés")
    days_worked = pd.DataFrame(np.array([workers]).T, columns=["Workers"])
    for d in range(nb_days):
        days_worked[f"Day {d+1}"] = True
    edited_worked = row4[0].data_editor(days_worked, use_container_width=True, hide_index=True, key="days_worked")

    row5 = st.columns([2, 2, 2])
    submit = row5[1].form_submit_button("Submit")

 
with tables:
    row1 = st.columns([10])
    row1[0].header("Planning")
    row2 = st.columns([10])
    schedule_display = row2[0].dataframe(pd.DataFrame(columns=["Tasks"] + [f"Day {i+1}" for i in range(nb_days)]),
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
    payload_workers = []
    for worker in edited_worked.values:
        w = worker[0]
        days_off = [idx for idx, day in enumerate(worker[1:]) if day == False]
        payload_workers.append((w, days_off))
    
    payload = {
        "workers": payload_workers,
        "tasks": [(task_name1, nb_worker1, 1), (task_name2, nb_worker2, 1)],
        "nb_days": nb_days,
        "task_per_day": task_per_day,
        "cutoff_first": cutoff_first,
        "cutoff_last": cutoff_last
    }

    res = requests.post("http://localhost:8080/schedule", json=payload)
    all_agg = res.json()

    print(all_agg["display"])
    print(all_agg["type"])
    print(all_agg["time"])
    print(all_agg["jobs"])

    for layout, agg in zip([schedule_display, time_agg, task_agg, task_per_day_agg], ["display", "type", "time", "jobs"]):
        set_df(layout, all_agg[agg])

