import streamlit as st
from streamlit_tags import st_tags, st_tags_sidebar
import pandas as pd
import numpy as np
import requests


st.set_page_config(page_title="Autrans", page_icon="🧊", layout="wide")

@st.dialog("Schedule is not possible")
def sat_schedule(txt):
    st.markdown(f"<h3 style='text-align: center'>{txt}</h3>", unsafe_allow_html=True)
    col1, col2, col3 = st.columns([1,1,1])
    if col2.button("OK", use_container_width=True):
        st.rerun()

@st.dialog("Setting Error")
def setting_error(txt):
    st.markdown(f"<h3 style='text-align: center'>{txt}</h3>", unsafe_allow_html=True)
    col1, col2, col3 = st.columns([1,1,1])
    if col2.button("OK", use_container_width=True):
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

def display_task(task_name, nb_worker, i, with_range=True):
    task_row_i = st.columns([3, 3, 1], vertical_alignment='bottom')
    task_name_i = task_row_i[0].text_input(f"Task name", value=task_name, key=f"task_name_{i}",
                                            help="Name of the task")
    nb_worker_i = task_row_i[1].number_input("People required", value=nb_worker, key=f"task_workers_{i}",
                                            help="Number of people needed to complete the task")
    
    task_row_i[2].button("", icon=":material/close:", type="secondary", 
                        key=f"del_task_{i}", use_container_width=True,
                        on_click=del_task, args=[i])
    if with_range:
        task_start, task_end = st.select_slider("Select a range of days for the task", options=selected_days,
                                            value=(selected_days[0], selected_days[-1]), key=f"task_skip_{i}")
    else:
        task_start, task_end = selected_days[0], selected_days[-1]
    return task_name_i, nb_worker_i, task_start, task_end

def display_worker(worker_name, worker_days_off, i, with_days_off):
    if with_days_off:
        worker_row_i = st.columns([2, 3, 1], vertical_alignment="bottom")
        
        worker_name_i = worker_row_i[0].text_input(f"Name", value=worker_name, key=f"worker_name_{i}")
        worker_days_off_i = worker_row_i[1].multiselect("Days off", options=selected_days, default=worker_days_off, key=f"worker_days_off_{i}",
                                                    help="Select on which days this person will not be working")
        worker_row_i[2].button("", icon=":material/close:", type="secondary", 
                    key=f"del_worker_{i}", use_container_width=True,
                    on_click=del_worker, args=[i])
        
    else:
        worker_row_i = st.columns([4, 1], vertical_alignment="bottom")
        worker_name_i = worker_row_i[0].text_input(f"Name", value=worker_name, key=f"worker_name_{i}")
        worker_days_off_i = []
        worker_row_i[1].button("", icon=":material/close:", type="secondary", 
                    key=f"del_worker_{i}", use_container_width=True,
                    on_click=del_worker, args=[i])

    return worker_name_i, worker_days_off_i

def del_state_list(key, error_msg, i):
    print("del", key, i, len(st.session_state[key]))
    if len(st.session_state[key]) == 1:
        setting_error(error_msg)
    else:
        st.session_state[key] = [t for (j, t) in enumerate(st.session_state[key]) if j != i]

def del_task(i):
    del_state_list("tasks", "Cannot delete the last task", i)

def del_worker(i):
    del_state_list("workers",  "Cannot delete the last worker", i)

def add_task(): 
    print("add_task")
    
    if len(st.session_state['tasks']) > 20:
        setting_error("Limit of 20 tasks reached.")
    
    i = len(st.session_state['tasks'])
    st.session_state['tasks'].append((f"Task {i+1}", 2, 1, selected_days[0], selected_days[-1]))


def add_worker(): 
    print("add_worker")
    
    if len(st.session_state['workers']) > 20:
        setting_error("Limit of 20 people reached.")
    
    w_names, _ = zip(*st.session_state["workers"])
    w_names = [s.split(" ")[-1] for s in w_names]
    numbers = []
    for s in w_names:
        try:
            numbers.append(int(s))
        except:
            pass
    print(numbers)
    st.session_state['workers'].append((f"People {max(numbers)+1}", []))

def display_general_settings():
    header = st.columns([6])
    header[0].header("Settings")
    st.divider()

    settings_row1 = st.columns([2, 4, 2], vertical_alignment="center")
    nb_days = settings_row1[0].number_input("Number of days", value=7, max_value=20,
                                            help="Number of days for the planning")
    
    #weekday_display = settings_row1[1].toggle("Days of the week", value=False, help="Display planning with days of the week")
    weekday_display = settings_row1[1].pills("Display Settings", ["Numbers", "Days of the week"], default="Numbers", 
                                             selection_mode="single", help="Display planning with days of the week")
    
    if weekday_display == "Days of the week":
        start_with = settings_row1[2].selectbox("Start with", placeholder="Monday", options=weekdays,
                                                help="Start planning with a specific day")
        startday = weekdays.index(start_with)
        selected_days = [(weekdays[(startday+i)%7], (startday+i) // 7) for i in range(nb_days)]
        multiple_week = any(i>=1 for w, i in selected_days)

        if multiple_week:
            selected_days = [d + f" (W {1+i})" for d, i in selected_days]
        else:
            selected_days = [d for d, i in selected_days]
    else:
        selected_days = [f"Day {i+1}" for i in range(nb_days)]
    return nb_days, selected_days 

def display_task_section():
    task_row = st.columns([6]) 
    task_row[0].header("Tasks")

    if 'tasks' not in st.session_state:
        st.session_state['tasks'] = []
        default_task_nb = 3

        for i in range(default_task_nb):
            task_name_i, nb_worker_i, task_start_i, task_end_i = display_task(f"Task {i+1}", 2, i)
            st.session_state['tasks'].append((task_name_i, nb_worker_i, 1, task_start_i, task_end_i))
    else:   
        for (i, (task_name_i, nb_worker_i, _, _, _)) in enumerate(st.session_state['tasks']):
            task_name_i, nb_worker_i, task_start_i, task_end_i = display_task(task_name_i, 2, i)

    row_add = st.columns([2, 2, 2])
    btn_task = row_add[1].button("Add Task", icon=":material/add:", type="primary", on_click=add_task)

    task_per_day, _, _, _, _ = zip(*st.session_state['tasks'])
    return task_per_day

def display_worker_section():
    worker_row = st.columns([6])
    worker_row[0].header("Workers")
    
    worker_row1 = st.columns([2, 4], vertical_alignment="center")
    with_days_off = worker_row1[0].toggle("Add days off", value=False,
                                          help="Include holidays") 

    if with_days_off:
        balance_daysoff_btn = worker_row1[1].pills("Balance", ["Total days", "Work days"], default="Total days", 
                                            help="""On Total days, workers will have to catch up on their vacation days.
                                                On Work days, workers will work in proportion of theirs working days.""")
        if balance_daysoff_btn == "Work days":
            balance_daysoff = True
        else:
            balance_daysoff = False
    else:
        balance_daysoff = False

    if "workers" not in st.session_state:
        st.session_state["workers"] = []
        default_nb_worker = 4

        for i in range(default_nb_worker):
            worker_name_i, worker_days_off_i = display_worker(f"Person {i+1}", [], i, with_days_off)
            st.session_state["workers"].append((worker_name_i, worker_days_off_i))
    else:
        for (i, (worker_name_i, worker_days_off_i)) in enumerate(st.session_state["workers"]):
            worker_name_i, worker_days_off_i = display_worker(worker_name_i, worker_days_off_i, i, with_days_off)

    row_add = st.columns([2, 2, 2])
    btn_task = row_add[1].button("Add Worker", icon=":material/add:", type="primary", on_click=add_worker)
    return balance_daysoff

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

    nb_days, selected_days = display_general_settings()

    st.divider()

    task_per_day = display_task_section()

    st.divider()

    balance_daysoff = display_worker_section()
    
    workers, _ = zip(*st.session_state["workers"])
    workers = list(workers)

    st.divider()

    row5 = st.columns([2, 2, 2])
    submit = row5[1].button("Submit", type="primary")

 
with tables:
    schedule_display = make_table("Schedule", ["Tasks"] + selected_days)
    task_agg = make_table("Affectation per day", ["Days"] + workers)
    task_per_day_agg = make_table("Affectation per task", ["Tasks"] + workers)
    

if submit:
    print(st.session_state["workers"])
    print(st.session_state["tasks"])
    all_tasks = []
    for task_name, nb_people, difficulty, name_start, name_end in st.session_state["tasks"]:
        start = selected_days.index(name_start) +1
        end = selected_days.index(name_end) +1
        all_tasks.append((task_name, nb_people, difficulty, start, end))
    
    payload = {
        "workers": st.session_state["workers"],
        "tasks": all_tasks,
        "nb_days": nb_days,
        "task_per_day": task_per_day,
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
        
