import time
import requests
import http.client
import logging

if False:
    http.client.HTTPConnection.debuglevel = 1

    # You must initialize logging, otherwise you'll not see debug output.
    logging.basicConfig()
    logging.getLogger().setLevel(logging.DEBUG)
    requests_log = logging.getLogger("requests.packages.urllib3")
    requests_log.setLevel(logging.DEBUG)
    requests_log.propagate = True

payload = {'workers': [('Person 1', []), ('Person 2', []), ('Person 3', []), ('Person 4', [])], 
           'tasks': [('Task 1', 2, 1), ('Task 2', 2, 1), ('Task 3', 2, 1)], 
           'nb_days': 7, 
           'task_per_day': ('Task 1', 'Task 2', 'Task 3'), 
           'cutoff_first': 1, 
           'cutoff_last': 2, 
           'balance_daysoff': False}


t = time.time()
MAX_REQ = 5

for i in range(MAX_REQ):
    res1 = requests.get("http://127.0.0.1:8080/sat", json=payload)

btime = round(time.time() - t, 2)
print(f"{MAX_REQ} requests : {btime}s, thougput: {round(MAX_REQ / btime, 2)}")

t = time.time()
MAX_REQ = 5

for i in range(MAX_REQ):
    res1 = requests.get("http://127.0.0.1:8080/sat")

btime = round(time.time() - t, 2)
print(f"{MAX_REQ} requests : {btime}s, thougput: {round(MAX_REQ / btime, 2)}")

for i in range(MAX_REQ):
    res1 = requests.post("http://127.0.0.1:8080/sat", json=payload)

btime = round(time.time() - t, 2)
print(f"{MAX_REQ} requests : {btime}s, thougput: {round(MAX_REQ / btime, 2)}")