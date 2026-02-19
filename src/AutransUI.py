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


@st.dialog("Schedule is not possible", width="large")
def sat_schedule(txt, details=None):
    st.markdown(f"<h3 style='text-align: center; color: #dc3545;'>Schedule is not feasible</h3>", unsafe_allow_html=True)
    
    # Show the main message
    st.markdown("### 📊 Problem Summary")
    st.text(txt)
    
    # Show detailed diagnostics if available
    if details and isinstance(details, dict):
        st.markdown("---")
        st.markdown("### 🔍 Detailed Diagnostics")
        
        # Capacity analysis
        if "capacity" in details:
            capacity = details["capacity"]
            st.markdown("#### Capacity Analysis")
            col1, col2, col3 = st.columns(3)
            col1.metric("Total Slots Needed", capacity.get("total_slots", "N/A"))
            col2.metric("Available Worker-Days", capacity.get("available_worker_days", "N/A"))
            col3.metric("Utilization", f"{capacity.get('utilization_percent', 'N/A')}%")
            
            # Daily issues
            if capacity.get("daily_issues"):
                st.markdown("#### ⚠️ Daily Capacity Issues")
                for issue in capacity["daily_issues"][:5]:  # Show first 5
                    st.warning(issue)
        
        # Constraint details
        if "constraints" in details and details["constraints"]:
            st.markdown("#### 🔧 Constraint Requirements")
            st.markdown("*These are the requirements that couldn't be satisfied:*")
            for constraint in details["constraints"][:8]:  # Show first 8
                st.text(f"• {constraint}")
        
        # Failed level
        if "failed_level" in details:
            st.info(f"Failed at relaxation level {details['failed_level']}")
    
    # OK button
    col1, col2, col3 = st.columns([1,1,1])
    if col2.button("OK", use_container_width=True, type="primary"):
        st.rerun()

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

def make_table(title, columns):
    st.subheader(title)
    return st.empty()


def make_schedule(placeholder, df, colors):
    with placeholder.container():
        # df has columns ["Tasks"] + selected_days
        # colors is list of colors for each chore
        st.markdown("""
        <div style="background-color: rgb(16, 185, 129); padding: 10px; border-radius: 8px; text-align: center; margin-bottom: 20px;">
            <h2 style="color: white; margin: 0;">Schedule</h2>
        </div>
        """, unsafe_allow_html=True)

        if df.empty:
            st.markdown("##### Your Schedule is there")
            return
        
        start_date = st.session_state["start_date"]
        dates = [start_date + datetime.timedelta(days=i) for i in range(st.session_state["nb_days"])]
        
        for j, day in enumerate(selected_days):
            date_str = dates[j].strftime('%d/%m/%Y')
            with st.container():
                st.markdown(f"<h4 style='color: rgb(16, 185, 129);'>{date_str} - {day} - Day {j+1}</h4>", unsafe_allow_html=True)
                
                for i in range(len(df)):
                    chore_name = df.iloc[i, 0]
                    assignments = df.iloc[i, j+1]
                    if assignments and str(assignments).strip():
                        color = colors[i] if i < len(colors) else 'white'
                        names_list = str(assignments).split(', ')
                        names_html = '<br>'.join(names_list)
                        card_html = f"""
                        <div style="background-color: {color}; padding: 10px; margin: 5px 0; border-radius: 8px; border: 1px solid #ddd; padding-left: 20px;">
                            <strong>{chore_name}</strong><br>
                            {names_html}
                        </div>
                        """
                        st.markdown(card_html, unsafe_allow_html=True)

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
        
        worker_name_i = worker_row_i[0].text_input(f"worker name {i}", value=worker_name, key=f"worker_name_{i}", placeholder="name", label_visibility="collapsed")
        worker_days_off_i = worker_row_i[1].multiselect(f"days_off{i}", options=selected_days, default=worker_days_off, key=f"worker_days_off_{i}",
                                                    help="Select days off, leave empty for no days off", placeholder="days off", label_visibility="collapsed")
        worker_row_i[2].button("", icon=":material/close:", type="secondary", 
                    key=f"del_worker_{i}", use_container_width=True,
                    on_click=del_worker, args=[i])
        
    else:
        worker_row_i = st.columns([4, 1], vertical_alignment="bottom")
        worker_name_i = worker_row_i[0].text_input(f"worker name {i}", value=worker_name, key=f"worker_name_{i}", placeholder="name", label_visibility="collapsed")
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
    
    # Simply use the next index as the worker number
    next_number = len(st.session_state['workers']) + 1
    st.session_state['workers'].append((f"Person {next_number}", []))

def display_general_settings():
    settings_row = st.columns([3, 3, 3], vertical_alignment="center")
    
    trip_placeholder = st.session_state.get("trip_name", "My Trip")
    st.session_state["trip_name"] = settings_row[0].text_input("Trip Name", value=trip_placeholder, placeholder="Trip Name")
    
    start_date = st.session_state.get("start_date", datetime.date.today())
    st.session_state["start_date"] = settings_row[1].date_input("Start Date", value=start_date)
    
    nb_days = st.session_state.get("nb_days", 7)
    st.session_state["nb_days"] = settings_row[2].number_input("Duration (days)", value=nb_days, max_value=20)
    
    # Generate selected_days
    dates = [st.session_state["start_date"] + datetime.timedelta(days=i) for i in range(st.session_state["nb_days"])]
    week_numbers = [(d - st.session_state["start_date"]).days // 7 for d in dates]
    selected_days = [f"{d.strftime('%A')} (W {1 + w})" if w > 0 else d.strftime("%A") for d, w in zip(dates, week_numbers)]
    return st.session_state["nb_days"], selected_days

def display_chores_section():
    show_ranges = st.toggle("Show ranges", value=False, help="Show day range selectors for each chore")

    if 'chores' not in st.session_state:
        st.session_state['chores'] = []
        default_chore_names = ["Cooking", "Cleaning", "Shopping"]

        for i, chore_name in enumerate(default_chore_names):
            color = generate_pastel_color()
            chore_name_i, nb_worker_i, color_i, chore_start_i, chore_end_i = display_chore(chore_name, 2, color, i, with_range=show_ranges)
            st.session_state['chores'].append((chore_name_i, nb_worker_i, 1, chore_start_i, chore_end_i, color_i))
    else:   
        for (i, (chore_name_i, nb_worker_i, _, _, _, color)) in enumerate(st.session_state['chores']):
            chore_name_i, nb_worker_i, color_i, chore_start_i, chore_end_i = display_chore(chore_name_i, nb_worker_i, color, i, with_range=show_ranges)
            st.session_state['chores'][i] = (chore_name_i, nb_worker_i, 1, chore_start_i, chore_end_i, color_i)

    row_add = st.columns([2, 2, 2])
    st.markdown('<div class="action-button">', unsafe_allow_html=True)
    btn_chore = row_add[1].button("Add Task", icon=":material/add:", type="primary", key="btn_add_chore", on_click=add_chore)
    st.markdown('</div>', unsafe_allow_html=True)

    task_per_day, _, _, _, _, _ = zip(*st.session_state['chores'])

    st.session_state[f"chore_names"] = [st.session_state[f"chore_name_{i}"] for i in range(len(st.session_state['chores']))]

    return task_per_day


def on_save_state():
    only_keys = [k for k in list(st.session_state.keys()) if k not in ["load_state", "save_state", "submit"]]
    only_keys = [k for k in only_keys if ("del" not in k) and ("btn" not in k)]

    serialized_state = {}
    for k in only_keys:
        value = st.session_state[k]
        # Convert datetime.date to string for JSON serialization
        if isinstance(value, datetime.date):
            serialized_state[k] = value.isoformat()
        else:
            serialized_state[k] = value
    
    serialized_state = json.dumps(serialized_state).encode()
    d = zlib.compress(serialized_state, level=9)
    c = base64.b64encode(d).decode('utf-8')
    pyperclip.copy(c)


# eNp1UsGKwjAQ/ZUhpxV6aOLCgmfZ24IHwUORkKUplrqJZCJFxH/fybTaautt8uZN3nuZXEU02Ghn/qzOxQrEVokMBEYTom7reEjYj3eluSQ8kZGgohBbKkESqDKQ1FqbCx+5+BL7DHqOes8hkmh9aGwYOdgwo6oDRk2ymjVlEr1rvo5JHlN3g7rrIV/3SeDRvLlKja7qY22o8o5dFnsO0SNqgiw7ZOSGNFD7qtKKNb5DTQh87EAuOiV60AeJKDGcLcHul0ECZP4STXG05SRaCqEm0eaTDbY4+lwj58mdLZ3FwTIRJxGG78Kv/tiwaK1tkpGyxtORfsuKt4zgK4gHC6k9s9entd7+AdJsxsA=

def on_load_state(state):
    state = base64.b64decode(state)
    state = zlib.decompress(state)
    state = json.loads(state)

    # Clear widget-related keys to avoid conflicts
    widget_keys = [k for k in st.session_state.keys() if k.startswith(("chore_name_", "chore_workers_", "chore_color_", "chore_range_", "worker_name_", "worker_days_off_"))]
    for k in widget_keys:
        del st.session_state[k]

    for k, v in state.items():
        if "del" in k:
            continue
        if "btn_add" in k:
            continue
        if k in ["load_state", "save_state", "submit"]:
            continue
        
        # Convert date strings back to datetime.date objects
        if k == "start_date" and isinstance(v, str):
            st.session_state[k] = datetime.date.fromisoformat(v)
        else:
            st.session_state[k] = v

def display_worker_section():
    if 'with_days_off' not in st.session_state:
        st.session_state['with_days_off'] = True

    if "workers" not in st.session_state:
        st.session_state["workers"] = []
        default_worker_names = ["Alex", "Benjamin", "Caroline", "Diane", "Esteban", "Frank"]

        for i, name in enumerate(default_worker_names):
            worker_name_i, worker_days_off_i = display_worker(name, [], i)
            st.session_state["workers"].append((worker_name_i, worker_days_off_i))
    else:
        for (i, (worker_name_i, worker_days_off_i)) in enumerate(st.session_state["workers"]):
            worker_name_i, worker_days_off_i = display_worker(worker_name_i, worker_days_off_i, i)

    row_add = st.columns([2, 3, 1])
    st.markdown('<div class="action-button">', unsafe_allow_html=True)
    btn_task = row_add[1].button("Add Worker", icon=":material/add:", type="primary", on_click=add_worker)
    st.markdown('</div>', unsafe_allow_html=True)

    balance_row = st.columns([2, 4])
    balance_row[0].markdown("**Balance:**")
    default = st.session_state.get("balance_daysoff_btn", "Days off")

    st.session_state['balance_daysoff_btn'] = balance_row[1].pills("balance_daysoff", ["Days off", "Ignore days off"], default=default, label_visibility="collapsed",
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
            .action-button .stButton button {
                background-color: #28a745 !important;
                color: white !important;
                border-color: #28a745 !important;
            }
            .action-button .stButton button:hover {
                background-color: #218838 !important;
                border-color: #218838 !important;
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
with settings:
    with st.container(border=True):
        st.markdown("### ⚙️ General Settings")
        nb_days, selected_days = display_general_settings()
    
    with st.container(border=True):
        st.markdown("### 📋 Tasks")
        chore_per_day = display_chores_section()
    
    with st.container(border=True):
        st.markdown("### 👥 Workers")
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
    st.markdown('<div class="action-button">', unsafe_allow_html=True)
    submit = row6[1].button("Submit", type="primary", key="submit")
    st.markdown('</div>', unsafe_allow_html=True)


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

        colors = [color for _, _, _, _, _, color in st.session_state['chores']]
        payload_sched = all_agg["display"]
        data = np.array(payload_sched["columns"]).T
        df = pd.DataFrame(data, columns=payload_sched["colindex"]["names"])
        st.session_state['schedule_df'] = df
        st.session_state['schedule_colors'] = colors

        st.session_state['grid_data'] = all_agg["display"]
        st.session_state['time_data'] = all_agg["time"]
        st.session_state['jobs_data'] = all_agg["jobs"]
        
        # Store export payload for later use
        st.session_state['export_workers'] = workers
        st.session_state['export_tasks'] = all_tasks
        st.session_state['export_balance'] = balance_daysoff
    else:
        # Pass detailed diagnostics if available
        details = sat_agg.get("details", None)
        sat_schedule(sat_agg["msg"], details)
 

with tables:
    with st.container(border=True):
        tabs = st.tabs(["Schedule", "Grid", "Audit", "Export"])
    with tabs[0]:
        schedule_placeholder = st.empty()
        if 'schedule_df' in st.session_state:
            make_schedule(schedule_placeholder, st.session_state['schedule_df'], st.session_state['schedule_colors'])
        else:
            schedule_placeholder.markdown("Your schedule is here")
    with tabs[1]:
        schedule_grid = make_table("Schedule", ["Tasks"] + selected_days)
        if 'grid_data' in st.session_state:
            set_df(schedule_grid, st.session_state['grid_data'])
    with tabs[2]:
        schedule_grid_audit = make_table("Schedule", ["Tasks"] + selected_days)
        if 'grid_data' in st.session_state:
            set_df(schedule_grid_audit, st.session_state['grid_data'])
        task_agg = make_table("Affectation per day", ["Days"] + workers)
        if 'time_data' in st.session_state:
            set_df(task_agg, st.session_state['time_data'])
        task_per_day_agg = make_table("Affectation per task", ["Tasks"] + workers)
        if 'jobs_data' in st.session_state:
            set_df(task_per_day_agg, st.session_state['jobs_data'])
        
        # Add legend
        st.markdown("---")
        st.markdown("### 📖 Legend")
        st.markdown("""
        **Understanding the Audit Tables:**
        
        - **Schedule**: Shows which workers are assigned to each task on each day
        - **Affectation per day**: Shows how many tasks each worker does per day (and total)
        - **Affectation per task**: Shows how many times each worker does each task (and total)
        
        **Notation:**
        - **\*** (asterisk) = Worker had a day off on that day/task period
        - Numbers with * indicate work done despite having days off in that period
        - TOTAL row/column shows the sum across all days/tasks
        """)
    with tabs[3]:
        if 'grid_data' in st.session_state:
            st.markdown("""
            <div style="background-color: rgb(16, 185, 129); padding: 10px; border-radius: 8px; text-align: center; margin-bottom: 20px;">
                <h2 style="color: white; margin: 0;">📥 Export Your Schedule</h2>
            </div>
            """, unsafe_allow_html=True)
            
            st.markdown("### Choose your export format:")
            st.markdown("")
            
            col1, col2 = st.columns(2)
            
            # Prepare payload with start_date and trip_name
            export_payload = {
                "workers": st.session_state.get('export_workers', []),
                "tasks": st.session_state.get('export_tasks', []),
                "nb_days": st.session_state.get('nb_days', 7),
                "balance_daysoff": st.session_state.get('export_balance', False),
                "start_date": st.session_state["start_date"].isoformat(),
                "trip_name": st.session_state.get('trip_name', 'My_Trip')
            }
            
            with col1:
                    if st.button("📅 Download iCalendar (.ics)", type="primary", use_container_width=True):
                        try:
                            res = requests.post("http://127.0.0.1:8080/export/ics", json=export_payload)
                            if res.status_code == 200:
                                st.download_button(
                                    label="💾 Save autrans-schedule.ics",
                                    data=res.content,
                                    file_name="autrans-schedule.ics",
                                    mime="text/calendar",
                                    use_container_width=True
                                )
                                st.success("✅ iCalendar file ready for download!")
                            else:
                                st.error(f"❌ Export failed: {res.json().get('error', 'Unknown error')}")
                        except Exception as e:
                            st.error(f"❌ Error: {str(e)}")
                    
                    st.markdown("")
                    st.markdown("**Compatible with:**")
                    st.markdown("- Microsoft Outlook")
                    st.markdown("- Google Calendar")
                    st.markdown("- Apple Calendar")
                    st.markdown("- Any calendar app")
            
            with col2:
                    if st.button("📊 Download CSV", type="primary", use_container_width=True):
                        try:
                            res = requests.post("http://127.0.0.1:8080/export/csv", json=export_payload)
                            if res.status_code == 200:
                                st.download_button(
                                    label="💾 Save autrans-schedule.csv",
                                    data=res.content,
                                    file_name="autrans-schedule.csv",
                                    mime="text/csv",
                                    use_container_width=True
                                )
                                st.success("✅ CSV file ready for download!")
                            else:
                                st.error(f"❌ Export failed: {res.json().get('error', 'Unknown error')}")
                        except Exception as e:
                            st.error(f"❌ Error: {str(e)}")
                    
                    st.markdown("")
                    st.markdown("**Compatible with:**")
                    st.markdown("- Microsoft Excel")
                    st.markdown("- Google Sheets")
                    st.markdown("- LibreOffice Calc")
                    st.markdown("- Any spreadsheet app")
            
            st.markdown("---")
            st.markdown("### 📖 Import Instructions")
            
            with st.expander("📅 How to import iCalendar (.ics) files"):
                    st.markdown("""
                    **Microsoft Outlook:**
                    1. Open Outlook
                    2. Go to File → Open & Export → Import/Export
                    3. Select "Import an iCalendar (.ics) file"
                    4. Browse to the downloaded file
                    
                    **Google Calendar:**
                    1. Open Google Calendar
                    2. Click the gear icon → Settings
                    3. Select "Import & Export" from the left menu
                    4. Click "Select file from your computer"
                    5. Choose the downloaded .ics file
                    
                    **Apple Calendar:**
                    1. Open Calendar app
                    2. Go to File → Import
                    3. Select the downloaded .ics file
                    """)
            
            with st.expander("📊 How to open CSV files"):
                    st.markdown("""
                    **Microsoft Excel:**
                    1. Open Excel
                    2. Go to File → Open
                    3. Select the downloaded .csv file
                    
                    **Google Sheets:**
                    1. Open Google Sheets
                    2. Go to File → Import
                    3. Upload the .csv file
                    
                    **Double-click:**
                    - Most systems will open CSV files in your default spreadsheet app
                    """)
        else:
            st.info("📋 Generate a schedule first to enable export options")
        
