import streamlit as st
from streamlit_tags import st_tags, st_tags_sidebar
import pandas as pd
import numpy as np
import zlib
import requests
import base64
import json
import pyperclip
import time
import random
import datetime

st.set_page_config(page_title="Autrans", page_icon="🧊", layout="wide")

def generate_pastel_color():
    r = random.randint(127, 255)
    g = random.randint(127, 255)
    b = random.randint(127, 255)
    return f"#{r:02x}{g:02x}{b:02x}"

def h3_button(txt):
    st.markdown(f"<h3 style='text-align: center'>{txt}</h3>", unsafe_allow_html=True)
    col1, col2, col3 = st.columns([1,1,1])
    if col2.button("OK", use_container_width=True):
        st.rerun()


@st.dialog("Schedule is not possible")
def sat_schedule(txt):
    h3_button(txt)

@st.dialog("Setting Error")
def setting_error(txt):
    h3_button(txt)

def set_df(layout, payload, cols=[], colors=None):
    data = np.array(payload["columns"]).T
    df = pd.DataFrame(data, columns=payload["colindex"]["names"])
    if cols != []:
        df.columns = cols
    if colors:
        def color_row(row):
            color = colors[row.name] if row.name < len(colors) else 'white'
            return [f'background-color: {color}'] * len(row)
        styled_df = df.style.apply(color_row, axis=1)
        layout.dataframe(styled_df, use_container_width=True, hide_index=True)
    else:
        layout.dataframe(df, use_container_width=True, hide_index=True)


def make_table(title, cols):
    row1 = st.columns([10])
    row1[0].markdown(f"<h3 style='text-align: center;'>{title}</h3>", unsafe_allow_html=True)

    row2 = st.columns([10])
    return row2[0].dataframe(pd.DataFrame(columns=cols), hide_index=True, use_container_width=True)

def update_state(text, i):
    print(text, i)
    print(st.session_state[f"chore_name_{i}"])

def display_chore(chore_name, nb_worker, color, i, with_range=False):
    chore_row_i = st.columns([2, 2, 2, 1], vertical_alignment='bottom')
    chore_name_i = chore_row_i[0].text_input(f"name", value=chore_name, key=f"chore_name_{i}", label_visibility="collapsed",
                                            help="Name of the chore")
    nb_worker_i = chore_row_i[1].number_input("number of worker", value=nb_worker, key=f"chore_workers_{i}",
                                            help="Number of people needed to complete the chore", label_visibility="collapsed")
    color_i = chore_row_i[2].color_picker("color", value=color, key=f"chore_color_{i}",
                                         help="Choose a color for this chore", label_visibility="collapsed")
    
    chore_row_i[3].button("", icon=":material/close:", type="secondary", 
                        key=f"del_chore_{i}", use_container_width=True,
                        on_click=del_chore, args=[i])
    if with_range:
        chore_start, chore_end = st.slider("chore range", 0, len(selected_days)-1, (0, len(selected_days)-1), key=f"chore_range_{i}", label_visibility="collapsed")
    else:
        chore_start, chore_end = 0, len(selected_days)-1
    return chore_name_i, nb_worker_i, color_i, chore_start, chore_end

def display_worker(worker_name, worker_days_off, i):
    if st.session_state['with_days_off']:
        worker_row_i = st.columns([2, 3, 1], vertical_alignment="bottom")
        
        worker_name_i = worker_row_i[0].text_input("", value=worker_name, key=f"worker_name_{i}", placeholder="Bob, Alice...", label_visibility="collapsed")
        worker_days_off_i = worker_row_i[1].multiselect("", options=selected_days, default=worker_days_off, key=f"worker_days_off_{i}",
                                                    help="Select days off, leave empty for no days off", label_visibility="collapsed")
        worker_row_i[2].button("", icon=":material/close:", type="secondary", 
                    key=f"del_worker_{i}", use_container_width=True,
                    on_click=del_worker, args=[i])
        
    else:
        worker_row_i = st.columns([4, 1], vertical_alignment="bottom")
        worker_name_i = worker_row_i[0].text_input("", value=worker_name, key=f"worker_name_{i}", placeholder="Bob, Alice...", label_visibility="collapsed")
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

def del_chore(i):
    del_state_list("chores", "Cannot delete the last chore", i)

def del_worker(i):
    del_state_list("workers",  "Cannot delete the last worker", i)

def add_chore(): 
    print("add_chore")
    
    if len(st.session_state['chores']) > 20:
        setting_error("Limit of 20 chores reached.")
    
    i = len(st.session_state['chores'])
    color = generate_pastel_color()
    st.session_state['chores'].append((f"Chore {i+1}", 2, 1, 0, st.session_state["nb_days"] - 1, color))

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
    
    st.session_state['workers'].append((f"People {max(numbers)+1}", []))

def display_general_settings():

    with st.container(border=True):
        header = st.columns([6])
        header[0].markdown("### ⚙️ Settings")
        
        settings_row = st.columns([3, 3, 3], vertical_alignment="center")
        
        if "trip_name" not in st.session_state:
            trip_placeholder = "My Trip"
        else:
            trip_placeholder = st.session_state["trip_name"]
        st.session_state["trip_name"] = settings_row[0].text_input("Trip Name", value=trip_placeholder, placeholder="Trip Name")
        
        if "start_date" not in st.session_state:
            start_date = datetime.date.today()
        else:
            start_date = st.session_state["start_date"]
        st.session_state["start_date"] = settings_row[1].date_input("Start Date", value=start_date)
        
        if "nb_days" not in st.session_state:
            nb_days = 7
        else:
            nb_days = st.session_state["nb_days"]
        st.session_state["nb_days"] = settings_row[2].number_input("Duration (days)", value=nb_days, max_value=20)
        
        # Generate selected_days
        dates = [st.session_state["start_date"] + datetime.timedelta(days=i) for i in range(st.session_state["nb_days"])]
        week_numbers = [(d - st.session_state["start_date"]).days // 7 for d in dates]
        selected_days = [f"{d.strftime('%A')} (W {1 + w})" if w > 0 else d.strftime("%A") for d, w in zip(dates, week_numbers)]
    return st.session_state["nb_days"], selected_days 

def display_chores_section():
    with st.container(border=True):
        chore_row = st.columns([6]) 
        chore_row[0].markdown("#### 🧹 Chores")

        show_ranges = st.toggle("Show ranges", value=False, help="Show day range selectors for each chore")

        if 'chores' not in st.session_state:
            st.session_state['chores'] = []
            default_chore_nb = 3

            for i in range(default_chore_nb):
                color = generate_pastel_color()
                chore_name_i, nb_worker_i, color_i, chore_start_i, chore_end_i = display_chore(f"Chore {i+1}", 2, color, i, with_range=show_ranges)
                st.session_state['chores'].append((chore_name_i, nb_worker_i, 1, chore_start_i, chore_end_i, color_i))
        else:   
            for (i, (chore_name_i, nb_worker_i, _, _, _, color)) in enumerate(st.session_state['chores']):
                chore_name_i, nb_worker_i, color_i, chore_start_i, chore_end_i = display_chore(chore_name_i, nb_worker_i, color, i, with_range=show_ranges)
                st.session_state['chores'][i] = (chore_name_i, nb_worker_i, 1, chore_start_i, chore_end_i, color_i)

        row_add = st.columns([2, 2, 2])
        btn_chore = row_add[1].button("Add Chore", icon=":material/add:", type="primary", key="btn_add_chore", on_click=add_chore)

        task_per_day, _, _, _, _, _ = zip(*st.session_state['chores'])

        st.session_state[f"chore_names"] = [st.session_state[f"chore_name_{i}"] for i in range(len(st.session_state['chores']))]

        return task_per_day


def on_save_state():
    only_keys = [k for k in list(st.session_state.keys()) if k not in ["load_state", "save_state", "submit"]]
    only_keys = [k for k in only_keys if ("del" not in k) and ("btn" not in k)]

    serialized_state = {k: st.session_state[k] for k in only_keys}
    serialized_state = json.dumps(serialized_state).encode()
    d = zlib.compress(serialized_state, level=9)
    c = base64.b64encode(d).decode('utf-8')
    pyperclip.copy(c)


# eNp1UsGKwjAQ/ZUhpxV6aOLCgmfZ24IHwUORkKUplrqJZCJFxH/fybTaautt8uZN3nuZXEU02Ghn/qzOxQrEVokMBEYTom7reEjYj3eluSQ8kZGgohBbKkESqDKQ1FqbCx+5+BL7DHqOes8hkmh9aGwYOdgwo6oDRk2ymjVlEr1rvo5JHlN3g7rrIV/3SeDRvLlKja7qY22o8o5dFnsO0SNqgiw7ZOSGNFD7qtKKNb5DTQh87EAuOiV60AeJKDGcLcHul0ECZP4STXG05SRaCqEm0eaTDbY4+lwj58mdLZ3FwTIRJxGG78Kv/tiwaK1tkpGyxtORfsuKt4zgK4gHC6k9s9entd7+AdJsxsA=

def on_load_state(state):
    state = base64.b64decode(state)
    state = zlib.decompress(state)
    state = json.loads(state)

    for k, v in state.items():
        if "del" in k:
            continue
        if "btn_add" in k:
            continue
        if k in ["load_state", "save_state", "submit"]:
            continue
        st.session_state[k] = v

def display_worker_section():
    with st.container(border=True):
        worker_row = st.columns([6])
        worker_row[0].markdown("#### 👥 Workers")
        
        worker_row1 = st.columns([2, 4], vertical_alignment="center")

        if 'with_days_off' not in st.session_state:
            st.session_state['with_days_off'] = True

        if "workers" not in st.session_state:
            st.session_state["workers"] = []
            default_nb_worker = 4

            for i in range(default_nb_worker):
                worker_name_i, worker_days_off_i = display_worker(f"Person {i+1}", [], i)
                st.session_state["workers"].append((worker_name_i, worker_days_off_i))
        else:
            for (i, (worker_name_i, worker_days_off_i)) in enumerate(st.session_state["workers"]):
                worker_name_i, worker_days_off_i = display_worker(worker_name_i, worker_days_off_i, i)

        row_add = st.columns([2, 2, 2])
        btn_task = row_add[1].button("Add Worker", icon=":material/add:", type="primary", on_click=add_worker)

        balance_row = st.columns([2, 4])
        balance_row[0].markdown("**Balance:**")
        if "balance_daysoff_btn" in st.session_state:
            default = st.session_state["balance_daysoff_btn"]
        else:
            default = "Days off"
        st.session_state['balance_daysoff_btn'] = balance_row[1].pills("", ["Days off", "Ignore days off"], default=default, label_visibility="collapsed",
                                            help="""With days off balance, workers will work in proportion of theirs working days.
                                            With Ignore days off, workers will work in proportion of total days (including their days off).""")
        if st.session_state['balance_daysoff_btn'] == "Days off":
            balance_daysoff = True
        else:
            balance_daysoff = False
    return balance_daysoff

if True:
    st.markdown("""
        <style>
            .reportview-container {
                margin-top: -2em;
            }
            #MainMenu {visibility: hidden;}
            .stDeployButton {display:none;}
            footer {visibility: hidden;}
            #stDecoration {display:none;}
            .stButton button {
                background-color: #28a745 !important;
                color: white !important;
                border-color: #28a745 !important;
            }
            .stButton button:hover:not([data-testid*="secondary"]) {
                background-color: #218838 !important;
                border-color: #218838 !important;
            }
            .stButton button[data-testid*="secondary"]:hover {
                background-color: #ffffff !important;
                border-color: #31333f33 !important;
            }
        </style>
    """, unsafe_allow_html=True)

st.markdown("<h1 style='text-align: center;'>Autrans</h1>", unsafe_allow_html=True)
st.markdown("<h2 style='text-align: center;'>Automated Scheduling Tool</h2>", unsafe_allow_html=True)

st.header("👋 Welcome to Autrans !")

st.markdown("""
Autrans is a simple yet powerful tool designed to take the headache out of trip scheduling with your friends. <br>
In just a few clicks, you can define your time range, list your tasks, and assign available <del>workers</del> people.<br>
Autrans automatically generates an optimized plan where: <br>
- Each people will have a fair share of the workload
- Each people will participate to each task
- <del>Workers</del> People can take days-offs, and the workload will be adjusted accordingly.
 <br>
""", unsafe_allow_html=True)


settings, tables = st.columns([4, 8])

weekdays = ["Monday", "Tuesday" , "Wednesday", "Thursday" , "Friday", "Saturday", "Sunday"]
with settings.container(border=True):

    nb_days, selected_days = display_general_settings()

    chore_per_day = display_chores_section()

    balance_daysoff = display_worker_section()
    
    workers, _ = zip(*st.session_state["workers"])
    workers = list(workers)
    
    with st.container(border=True):
        row4 = st.text_input("State Input")
        row5 = st.columns([2, 2, 2])
        row7 = st.columns([2, 2, 2])

        load_state = row5[2].button("Load State", type="secondary", key="load_state", 
                                    on_click= lambda : on_load_state(str(row4)))

        save_state = row5[0].button("Copy State", type="secondary", key="save_state", 
                                    on_click=on_save_state)

        if save_state:
            row7[0].badge("Copied to Clipboard", icon=":material/check:", color="green")

    row6 = st.columns([2, 2, 2])
    submit = row6[1].button("Submit", type="primary", key="submit")

 
with tables:
    with st.container(border=True):
        tabs = st.tabs(["Schedule", "Audit"])
        with tabs[0]:
            schedule_display = make_table("Schedule", ["Tasks"] + selected_days)
        with tabs[1]:
            schedule_display = make_table("Schedule", ["Tasks"] + selected_days)
            task_agg = make_table("Affectation per day", ["Days"] + workers)
            task_per_day_agg = make_table("Affectation per task", ["Tasks"] + workers)


if submit:
    all_tasks = []

    st.session_state[f"chore_names"] = [st.session_state[f"chore_name_{i}"] for i in range(len(st.session_state['chores']))]

    for i, (chore_name, nb_people, difficulty, name_start, name_end, color) in enumerate(st.session_state["chores"]):
        #print(selected_days, name_start)
        chore_name = st.session_state[f"chore_name_{i}"]
        nb_people = st.session_state[f"chore_workers_{i}"]
        #start = selected_days.index(name_start) +1
        #end = selected_days.index(name_end) +1
        
        start = name_start + 1
        end = name_end + 1
        
        all_tasks.append((chore_name, nb_people, difficulty, start, end))

    workers = []
    for i in range(len(st.session_state["workers"])):
        w_name = st.session_state[f"worker_name_{i}"]
        if f"worker_days_off_{i}" in st.session_state:
            w_days_off = st.session_state[f"worker_days_off_{i}"]
            w_days_off_idx = [selected_days.index(d)+1 for d in w_days_off]
        else:
            w_days_off_idx = []
        workers.append((w_name, w_days_off_idx))

    payload = {
        "workers": workers,
        "tasks": all_tasks,
        "nb_days": nb_days,
        "task_per_day": [b[0] for b in all_tasks],
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
                colors = [color for _, _, _, _, _, color in st.session_state['chores']]
                set_df(layout, all_agg[agg], ["Tasks"] + selected_days, colors=colors)
            else:
                set_df(layout, all_agg[agg])
    else:
        sat_schedule(sat_agg["msg"])
        
