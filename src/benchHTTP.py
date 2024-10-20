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

payload = {'workers': [('Person 1', []), ('Person 2', []), ('Person 3', []), ('Person 4', []), ('Person ', [])], 
           'tasks': [(f'Task {i}', 2, 1) for i in range(10)], 
           'nb_days': 20, 
           'task_per_day': ('Task 1', 'Task 2', 'Task 3', 'Task 4', 'Task 5', 'Task 6', 'Task 7', 'Task 8', 'Task 9', 'Task 10'), 
           'cutoff_first': 1, 
           'cutoff_last': 2, 
           'balance_daysoff': False}


print("cold start")
res1 = requests.get("http://127.0.0.1:8080/sat")
res1 = requests.post("http://127.0.0.1:8080/sat", json=payload)
res1 = requests.post("http://127.0.0.1:8080/schedule", json=payload)


t = time.time()
MAX_REQ = 1000
for i in range(MAX_REQ):
    res1 = requests.get("http://127.0.0.1:8080/sat")

btime = round(time.time() - t, 2)
print(f"{MAX_REQ} requests : {btime}s, thougput: {round(MAX_REQ / btime, 2)}req/s")

t = time.time()
for i in range(MAX_REQ):
    res1 = requests.post("http://127.0.0.1:8080/sat", json=payload)

btime = round(time.time() - t, 2)
print(f"{MAX_REQ} requests : {btime}s, thougput: {round(MAX_REQ / btime, 2)}req/s")


t = time.time()
for i in range(MAX_REQ):
    res1 = requests.post("http://127.0.0.1:8080/schedule", json=payload)

btime = round(time.time() - t, 2)
print(f"{MAX_REQ} requests : {btime}s, thougput: {round(MAX_REQ / btime, 2)}req/s")