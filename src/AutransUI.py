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

def display_worker(worker_name, worker_days_off, i, task_names):
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
    
    # Show task preferences if enabled
    worker_preferences_i = []
    if st.session_state.get('show_preferences', False) and task_names:
        # Initialize preference list if not exists
        if f"worker_pref_list_{i}" not in st.session_state:
            st.session_state[f"worker_pref_list_{i}"] = []
        
        pref_list = st.session_state[f"worker_pref_list_{i}"]
        
        # Get available tasks (not yet in preference list)
        available_tasks = [t for t in task_names if t not in pref_list]
        
        # Dropdown to add tasks
        if available_tasks:
            add_col1, add_col2 = st.columns([3, 1])
            selected_to_add = add_col1.selectbox(
                "Add task preference",
                options=["Select task..."] + available_tasks,
                key=f"worker_{i}_add_pref",
                label_visibility="collapsed"
            )
            
            if add_col2.button("Add", key=f"worker_{i}_add_btn", use_container_width=True):
                if selected_to_add != "Select task...":
                    pref_list.append(selected_to_add)
                    st.session_state[f"worker_pref_list_{i}"] = pref_list
                    st.rerun()
        
        # Display ranked preferences with up arrow and remove button
        if pref_list:
            st.markdown("**Ranked Preferences:**")
            for rank, task in enumerate(pref_list):
                pref_row = st.columns([1, 4, 1, 1], vertical_alignment="center")
                pref_row[0].markdown(f"**{rank + 1}.**")
                pref_row[1].markdown(task)
                
                # Up arrow (disabled for first item)
                if rank > 0:
                    if pref_row[2].button("↑", key=f"worker_{i}_up_{rank}", use_container_width=True):
                        # Swap with previous item
                        pref_list[rank], pref_list[rank-1] = pref_list[rank-1], pref_list[rank]
                        st.session_state[f"worker_pref_list_{i}"] = pref_list
                        st.rerun()
                else:
                    pref_row[2].empty()
                
                # Remove button
                if pref_row[3].button("×", key=f"worker_{i}_remove_{rank}", use_container_width=True):
                    pref_list.pop(rank)
                    st.session_state[f"worker_pref_list_{i}"] = pref_list
                    st.rerun()
        
        # Convert to backend format (1-based task indices)
        worker_preferences_i = [task_names.index(task) + 1 for task in pref_list]

    return worker_name_i, worker_days_off_i, worker_preferences_i

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

def del_hard_constraint(i):
    st.session_state['hard_constraints'] = [c for (j, c) in enumerate(st.session_state['hard_constraints']) if j != i]

def del_soft_constraint(i):
    st.session_state['soft_constraints'] = [c for (j, c) in enumerate(st.session_state['soft_constraints']) if j != i]

def add_hard_constraint():
    # All available constraints
    all_constraints = ["Task Coverage", "No Consecutive Tasks", "Days Off", 
                      "Overall Equity", "Daily Equity", "Task Diversity", "Worker Preference"]
    
    # Check if all constraints are already used
    used = st.session_state['hard_constraints'] + st.session_state['soft_constraints']
    available = [c for c in all_constraints if c not in used]
    
    if not available:
        setting_error("All constraints are already added")
        return
    
    # Add first available constraint
    st.session_state['hard_constraints'].append(available[0])

def add_soft_constraint():
    # All available constraints
    all_constraints = ["Task Coverage", "No Consecutive Tasks", "Days Off",
                      "Overall Equity", "Daily Equity", "Task Diversity", "Worker Preference"]
    
    # Check if all constraints are already used
    used = st.session_state['hard_constraints'] + st.session_state['soft_constraints']
    available = [c for c in all_constraints if c not in used]
    
    if not available:
        setting_error("All constraints are already added")
        return
    
    # Add first available constraint
    st.session_state['soft_constraints'].append(available[0])

def move_soft_constraint_up(i):
    if i > 0:
        constraints = st.session_state['soft_constraints']
        constraints[i], constraints[i-1] = constraints[i-1], constraints[i]
        st.session_state['soft_constraints'] = constraints

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
    # Exclude runtime results and non-serializable data
    exclude_keys = [
        "load_state", "save_state", "submit",
        "schedule_df", "schedule_colors",  # DataFrame and colors (runtime results)
        "grid_data", "time_data", "jobs_data",  # Schedule results
        "export_workers", "export_tasks", "export_balance",  # Export data
        "show_schedule"  # Runtime flag
    ]
    
    only_keys = [k for k in list(st.session_state.keys()) if k not in exclude_keys]
    only_keys = [k for k in only_keys if ("del" not in k) and ("btn" not in k) and ("add" not in k)]

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
    
    # Show task preferences toggle
    if 'show_preferences' not in st.session_state:
        st.session_state['show_preferences'] = False
    
    st.session_state['show_preferences'] = st.toggle("Show task preferences", 
                                                      value=st.session_state['show_preferences'],
                                                      help="Allow workers to rank tasks by preference")
    
    # Get task names for preferences
    task_names = st.session_state.get('chore_names', [])

    if "workers" not in st.session_state:
        st.session_state["workers"] = []
        default_worker_names = ["Alex", "Benjamin", "Caroline", "Diane", "Esteban", "Frank"]

        for i, name in enumerate(default_worker_names):
            worker_name_i, worker_days_off_i, worker_prefs_i = display_worker(name, [], i, task_names)
            st.session_state["workers"].append((worker_name_i, worker_days_off_i))
    else:
        for (i, (worker_name_i, worker_days_off_i)) in enumerate(st.session_state["workers"]):
            worker_name_i, worker_days_off_i, worker_prefs_i = display_worker(worker_name_i, worker_days_off_i, i, task_names)

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
        with st.expander("🔧 Advanced Settings", expanded=True):
            # Initialize constraint lists if not present
            if 'hard_constraints' not in st.session_state:
                st.session_state['hard_constraints'] = [
                    "Task Coverage",
                    "No Consecutive Tasks", 
                    "Days Off"
                ]
            
            if 'soft_constraints' not in st.session_state:
                st.session_state['soft_constraints'] = [
                    "Overall Equity",
                    "Daily Equity",
                    "Task Diversity"
                ]
            
            # Available constraint options with descriptions
            constraint_options = {
                "Task Coverage": "Each task must have the required number of workers",
                "No Consecutive Tasks": "Workers do at most one task per day",
                "Days Off": "Workers cannot work on their days off",
                "Overall Equity": "Fair distribution of total workload",
                "Daily Equity": "Similar amount of work per day",
                "Task Diversity": "Everyone participates in each task",
                "Worker Preference": "Respect worker task preferences (requires preferences enabled)"
            }
            
            st.markdown("#### Hard Constraints")
            st.markdown("*Must be satisfied for a valid schedule*")
            
            # Display hard constraints or empty state
            if len(st.session_state['hard_constraints']) == 0:
                st.info("ℹ️ No hard constraints selected. Click 'Add Hard Constraint' to add one.")
            
            for i, constraint in enumerate(st.session_state['hard_constraints']):
                constraint_row = st.columns([4, 1], vertical_alignment="bottom")
                
                # Get available options (exclude already selected constraints except current)
                used_constraints = (st.session_state['hard_constraints'][:i] + 
                                  st.session_state['hard_constraints'][i+1:] +
                                  st.session_state['soft_constraints'])
                available = [c for c in constraint_options.keys() if c not in used_constraints or c == constraint]
                
                selected = constraint_row[0].selectbox(
                    f"Hard constraint {i}",
                    options=available,
                    index=available.index(constraint) if constraint in available else 0,
                    key=f"hard_constraint_{i}",
                    help=constraint_options.get(constraint, ""),
                    label_visibility="collapsed"
                )
                st.session_state['hard_constraints'][i] = selected
                
                constraint_row[1].button("", icon=":material/close:", type="secondary",
                                       key=f"del_hard_constraint_{i}", use_container_width=True,
                                       on_click=del_hard_constraint, args=[i])
            
            # Add hard constraint button
            row_add_hard = st.columns([1, 3, 1])
            row_add_hard[1].button("Add Hard Constraint", icon=":material/add:", 
                                  type="primary", key="btn_add_hard_constraint",
                                  on_click=add_hard_constraint, use_container_width=True)
            
            st.markdown("#### Soft Constraints")
            st.markdown("*Relaxed if needed (order matters: first = highest priority)*")
            
            # Display soft constraints or empty state
            if len(st.session_state['soft_constraints']) == 0:
                st.info("ℹ️ No soft constraints selected. Click 'Add Soft Constraint' to add one.")
            
            for i, constraint in enumerate(st.session_state['soft_constraints']):
                constraint_row = st.columns([4, 1, 1], vertical_alignment="bottom")
                
                # Get available options
                used_constraints = (st.session_state['hard_constraints'] +
                                  st.session_state['soft_constraints'][:i] +
                                  st.session_state['soft_constraints'][i+1:])
                available = [c for c in constraint_options.keys() if c not in used_constraints or c == constraint]
                
                selected = constraint_row[0].selectbox(
                    f"Soft constraint {i}",
                    options=available,
                    index=available.index(constraint) if constraint in available else 0,
                    key=f"soft_constraint_{i}",
                    help=constraint_options.get(constraint, ""),
                    label_visibility="collapsed"
                )
                st.session_state['soft_constraints'][i] = selected
                
                # Move up/down buttons
                if i > 0:
                    constraint_row[1].button("", icon=":material/arrow_upward:", type="secondary",
                                           key=f"move_up_soft_{i}", use_container_width=True,
                                           on_click=move_soft_constraint_up, args=[i])
                else:
                    constraint_row[1].empty()
                
                constraint_row[2].button("", icon=":material/close:", type="secondary",
                                       key=f"del_soft_constraint_{i}", use_container_width=True,
                                       on_click=del_soft_constraint, args=[i])
            
            # Add soft constraint button
            row_add_soft = st.columns([1, 3, 1])
            row_add_soft[1].button("Add Soft Constraint", icon=":material/add:",
                                  type="primary", key="btn_add_soft_constraint",
                                  on_click=add_soft_constraint, use_container_width=True)
    
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
    task_names = st.session_state.get('chore_names', [])
    
    for i in range(len(st.session_state["workers"])):
        w_name = st.session_state[f"worker_name_{i}"]
        if f"worker_days_off_{i}" in st.session_state:
            w_days_off = st.session_state[f"worker_days_off_{i}"]
            w_days_off_idx = [selected_days.index(d)+1 for d in w_days_off]
        else:
            w_days_off_idx = []
        
        # Collect task preferences if enabled
        w_preferences = []
        if st.session_state.get('show_preferences', False) and task_names:
            for rank in range(len(task_names)):
                if f"worker_{i}_pref_rank_{rank}" in st.session_state:
                    task_name = st.session_state[f"worker_{i}_pref_rank_{rank}"]
                    task_idx = task_names.index(task_name) + 1  # 1-based index
                    w_preferences.append(task_idx)
        
        # Add worker with preferences (empty list if not using preferences)
        workers.append((w_name, w_days_off_idx, w_preferences))

    # Build constraint name lists from UI selections
    # Map display names to backend names
    constraint_name_map = {
        "Task Coverage": "TaskCoverage",
        "No Consecutive Tasks": "NoConsecutiveTasks",
        "Days Off": "DaysOff",
        "Overall Equity": "OverallEquity",
        "Daily Equity": "DailyEquity",
        "Task Diversity": "TaskDiversity",
        "Worker Preference": "WorkerPreference"
    }
    
    hard_constraints = [constraint_name_map[c] for c in st.session_state.get('hard_constraints', [])]
    soft_constraints = [constraint_name_map[c] for c in st.session_state.get('soft_constraints', [])]
    
    payload = {
        "workers": workers,
        "tasks": all_tasks,
        "nb_days": nb_days,
        "task_per_day": [b[0] for b in all_tasks],
        "balance_daysoff": balance_daysoff,
        "hard_constraints": hard_constraints,
        "soft_constraints": soft_constraints
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
        
        # Set flag to show schedule tab
        st.session_state['show_schedule'] = True
        
        # Show success message
        st.success("✅ Schedule generated successfully! Click the **Schedule** tab above to view it.", icon="🎉")
    else:
        # Pass detailed diagnostics if available
        details = sat_agg.get("details", None)
        sat_schedule(sat_agg["msg"], details)
 

with tables:
    with st.container(border=True):
        tabs = st.tabs(["Schedule", "Grid", "Audit", "Export", "Help"])
    
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
                    if st.button("📅 Download iCalendar (.ics)", type="primary", use_container_width=True, key="export_ics_btn"):
                        try:
                            res = requests.post("http://127.0.0.1:8080/export/ics", json=export_payload)
                            if res.status_code == 200:
                                # Generate filename from trip details
                                trip_name = st.session_state.get('trip_name', 'My_Trip').replace(' ', '_')
                                start_date = st.session_state["start_date"].isoformat()
                                nb_days = st.session_state.get('nb_days', 7)
                                filename = f"Schedule-{trip_name}-{start_date}-{nb_days}days.ics"
                                
                                st.download_button(
                                    label=f"💾 Save {filename}",
                                    data=res.content,
                                    file_name=filename,
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
                    if st.button("📊 Download CSV", type="primary", use_container_width=True, key="export_csv_btn"):
                        try:
                            res = requests.post("http://127.0.0.1:8080/export/csv", json=export_payload)
                            if res.status_code == 200:
                                # Generate filename from trip details
                                trip_name = st.session_state.get('trip_name', 'My_Trip').replace(' ', '_')
                                start_date = st.session_state["start_date"].isoformat()
                                nb_days = st.session_state.get('nb_days', 7)
                                filename = f"Schedule-{trip_name}-{start_date}-{nb_days}days.csv"
                                
                                st.download_button(
                                    label=f"💾 Save {filename}",
                                    data=res.content,
                                    file_name=filename,
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
    with tabs[4]:
        st.markdown("""
        <div style="background-color: rgb(16, 185, 129); padding: 10px; border-radius: 8px; text-align: center; margin-bottom: 20px;">
            <h2 style="color: white; margin: 0;">📚 Help & Documentation</h2>
        </div>
        """, unsafe_allow_html=True)
        
        # Getting Started
        with st.expander("🚀 Getting Started", expanded=True):
            st.markdown("""
            ### 👋 Welcome to Autrans!
            
            Autrans is a simple yet powerful tool designed to take the headache out of scheduling with your ~~workers~~ friends.
            
            In just a few clicks, you can define your time range, list your tasks, and assign available people.
            
            **Autrans automatically generates an optimized plan where:**
            - Each person will have a fair share of the workload
            - Each person will participate in each task
            - People can take days off, and the workload will be adjusted accordingly
            
            ---
            
            **Basic Workflow:**
            1. **Configure Settings** (left panel): Set your trip name, dates, and duration
            2. **Define Tasks**: Add the tasks that need to be done (cooking, cleaning, etc.)
            3. **Add Workers**: List all participants and their availability
            4. **Adjust Constraints** (optional): Fine-tune how the schedule is generated
            5. **Click Submit**: Generate your optimized schedule!
            6. **View & Export**: Check the results and export to your calendar
            
            **Quick Tips:**
            - Start with the default settings to see how it works
            - The system automatically ensures fairness and task coverage
            - You can customize everything to match your group's needs
            """)
        
        # Understanding Results
        with st.expander("📊 Understanding Results"):
            st.markdown("""
            ### How to Read Your Schedule
            
            After clicking Submit, you'll see several views of your schedule:
            
            **Schedule Tab** 📅
            - Visual calendar showing who does what each day
            - Color-coded by task for easy reading
            - Shows actual dates and day names
            
            **Grid Tab** 📋
            - Table format: Tasks × Days
            - Shows worker assignments for each task/day combination
            - Compact view of the entire schedule
            
            **Audit Tab** 📈
            - **Schedule**: Same as Grid tab
            - **Affectation per day**: How many tasks each person does per day
            - **Affectation per task**: How many times each person does each task
            - **Legend**: `*` indicates days off were involved
            
            **Export Tab** 💾
            - Download as iCalendar (.ics) for Outlook, Google Calendar, Apple Calendar
            - Download as CSV for Excel, Google Sheets
            - Filenames include trip name, date, and duration
            """)
        
        # General Settings
        with st.expander("⚙️ General Settings"):
            st.markdown("""
            ### Trip Configuration
            
            **Trip Name**
            - Give your trip a memorable name
            - Used in exported filenames
            - Example: "Summer Cabin 2026"
            
            **Start Date**
            - When does your trip begin?
            - Used to generate actual calendar dates
            - Helps with planning and coordination
            
            **Duration (days)**
            - How many days is your trip?
            - Maximum: 20 days
            - Affects workload distribution
            """)
        
        # Tasks Section
        with st.expander("📋 Tasks"):
            st.markdown("""
            ### Defining Your Tasks
            
            **What are Tasks?**
            - Activities that need to be done during your trip
            - Examples: Cooking, Cleaning, Shopping, Dishes, Trash
            - Each task can require multiple workers
            
            **Task Settings:**
            - **Name**: What the task is called
            - **Workers Needed**: How many people are required (e.g., 2 for cooking)
            - **Color**: Visual identifier in the schedule
            - **Range** (optional): Limit task to specific days
            
            **Tips:**
            - Be specific: "Breakfast" and "Dinner" instead of just "Cooking"
            - Consider task duration: Some tasks need more people
            - Use colors to group related tasks
            - You can have up to 20 tasks
            """)
        
        # Workers Section
        with st.expander("👥 Workers & Balance"):
            st.markdown("""
            ### Managing Participants
            
            **Adding Workers:**
            - List everyone participating in the trip
            - Each person can have days off
            - You can have up to 20 workers
            
            **Days Off:**
            - Select days when someone is unavailable
            - They won't be assigned tasks on those days
            - Affects workload distribution (see Balance below)
            
            **Task Preferences** (Optional):
            - When enabled, workers can rank tasks by preference
            - **How to use:**
              1. Select a task from the dropdown to add it to preferences
              2. Click "Add" to add it to the ranked list
              3. Use ↑ arrow to move tasks up (swap with item above)
              4. Click × to remove a task from preferences
              5. Leave empty if worker has no preferences
            - **How it affects scheduling:**
              - Ranked tasks: Worker is more likely to get these assignments
              - Unranked tasks: Worker is less likely to get these assignments
              - The scheduler tries to respect preferences while maintaining fairness
            - **Example:** If Alex ranks [Cleaning, Cooking], they'll get more Cleaning/Cooking and less Shopping
            
            ---
            
            ### ⚖️ Balance Settings - Why It Matters
            
            The Balance setting determines how workload is distributed when people have different availability.
            
            **"Days off" Balance** (Recommended) ✅
            - Workers work **proportionally to their available days**
            - **Fair**: People with fewer available days do less work
            - **Example**: 
              - Alice: 7 working days → 100% workload
              - Bob: 5 working days (2 days off) → 71% workload
              - Bob does 71% of Alice's work (5/7 = 0.71)
            
            **"Ignore days off" Balance**
            - Everyone works **equally regardless of days off**
            - **Equal**: Same total workload for everyone
            - **Example**:
              - Alice: 7 working days → 100% workload
              - Bob: 5 working days (2 days off) → 100% workload
              - Bob does the same amount as Alice, but in fewer days
            
            **When to Use Each:**
            - **Days off**: Most fair for trips where availability varies
            - **Ignore days off**: When you want strict equality regardless of circumstances
            
            **Why It Matters:**
            - Affects team morale and perceived fairness
            - Impacts schedule feasibility (tight schedules may need "Ignore days off")
            - Consider your group's preferences and dynamics
            """)
        
        # Advanced Settings
        with st.expander("🔧 Advanced Settings - Constraints"):
            st.markdown("""
            ### Understanding Constraints
            
            Constraints are **rules** that govern how your schedule is created. They ensure fairness, respect availability, and meet your requirements.
            
            ---
            
            ### Hard vs Soft Constraints
            
            **Hard Constraints** 🔴
            - **MUST be satisfied** for a valid schedule
            - If impossible, the schedule will fail
            - Use for non-negotiable requirements
            - Example: "Tasks must be covered" is typically hard
            
            **Soft Constraints** 🟡
            - **Preferred but flexible**
            - Can be relaxed if needed to find a solution
            - **Order matters**: First = highest priority
            - Use the ↑ button to reorder priorities
            
            **When to Use Each:**
            - Hard: Absolute requirements (safety, coverage, availability)
            - Soft: Preferences and optimization goals (fairness, diversity)
            
            ---
            
            ### Available Constraints
            
            **Task Coverage** 📋
            - **What**: Each task has the required number of workers
            - **Hard**: Tasks must be fully covered (no understaffing)
            - **Soft**: Tasks can be under-covered if necessary
            - **Why**: Ensures all work gets done
            - **Example**: If "Cooking" needs 2 people, exactly 2 are assigned
            
            **No Consecutive Tasks** 🚫
            - **What**: Workers do at most one task per day
            - **Hard**: Strict limit of 1 task/day
            - **Soft**: Can do multiple tasks if needed
            - **Why**: Prevents burnout and overwork
            - **Example**: Alice does Cooking OR Cleaning, not both
            
            **Days Off** 🏖️
            - **What**: Workers cannot work on their days off
            - **Hard**: Strictly respect days off
            - **Soft**: Can work on days off if absolutely necessary
            - **Why**: Respects personal plans and availability
            - **Example**: Bob has Monday off, so he's not assigned Monday tasks
            
            **Overall Equity** ⚖️
            - **What**: Fair distribution of total workload
            - **Hard**: Strict equality (everyone does similar total work)
            - **Soft**: Approximate equality (some variation allowed)
            - **Why**: Ensures no one is overworked
            - **Example**: Over 7 days, everyone does 6-8 tasks (not 2 vs 12)
            
            **Daily Equity** 📅
            - **What**: Similar amount of work each day
            - **Hard**: Strict daily limits
            - **Soft**: Flexible daily limits
            - **Why**: Prevents exhausting days
            - **Example**: No one does 3 tasks in one day while others do 0
            
            **Task Diversity** 🎯
            - **What**: Everyone participates in each task type
            - **Hard**: Strict participation requirements
            - **Soft**: Approximate participation
            - **Why**: Variety and skill sharing
            - **Example**: Everyone cooks at least once, not just 2 people cooking all week
            
            ---
            
            ### Choosing Your Constraints
            
            **Recommended Starting Point:**
            - **Hard**: Task Coverage, No Consecutive Tasks, Days Off
            - **Soft**: Overall Equity, Daily Equity, Task Diversity
            
            **Common Adjustments:**
            - Tight schedule? Make "No Consecutive Tasks" soft
            - Flexible group? Make "Days Off" soft
            - Want strict fairness? Make equity constraints hard
            - Prefer flexibility? Use more soft constraints
            
            **Priority Order (Soft Constraints):**
            - First constraint = highest priority (relaxed last)
            - Last constraint = lowest priority (relaxed first)
            - Use ↑ button to reorder
            - Example: If Overall Equity is first, it's protected the most
            """)
        
        # Tips and Tricks
        with st.expander("💡 Tips & Tricks"):
            st.markdown("""
            ### Getting the Best Results
            
            **For Feasible Schedules:**
            - Ensure enough workers for your tasks
            - Don't over-constrain (too many hard constraints)
            - Check capacity: (tasks × workers needed × days) ≤ (workers × available days)
            
            **For Fair Schedules:**
            - Use "Days off" balance mode
            - Keep Overall Equity as a constraint
            - Enable Task Diversity
            
            **For Flexible Schedules:**
            - Use more soft constraints
            - Make "No Consecutive Tasks" soft
            - Adjust constraint priorities
            
            **Troubleshooting:**
            - **"Schedule not feasible"**: Reduce hard constraints or add more workers
            - **Unfair distribution**: Check balance mode and equity constraints
            - **Someone overworked**: Enable Daily Equity constraint
            - **Tasks not covered**: Ensure Task Coverage is enabled
            
            **State Management:**
            - Use "Copy State" to save your configuration
            - Share the state code with your group
            - Use "Load State" to restore a saved configuration
            """)
    
