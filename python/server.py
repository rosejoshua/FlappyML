import socketserver, requests

REWARD = 0.08
PUNISHMENT = 0.07
REWARD_BUFFER = 0.02

agents:dict = {}
# states_and_outcomes:dict = {}
# total_survival = 0.0
# avg_survival = 0.0
# num_iters = 0
packets_received = 0

kill_requests = []

def lerpf(frm:float, to:float, dlt:float) -> float:
    return (frm * (1.0 - dlt)) + (to * dlt)

def punish(state:str, jumped:bool, id:int):
    if jumped:
        move_toward = 0.0
    else:
        move_toward = 1.0
    agents[id]["states"][state] = lerpf(agents[id]["states"][state], move_toward, PUNISHMENT)

def reward(state:str, jumped:bool, id:int):
    if jumped:
        move_toward = 1.0
    else:
        move_toward = 0.0
    # states_and_outcomes[state] = lerpf(states_and_outcomes.get(state), move_toward, REWARD)
    agents[id]["states"][state] = lerpf(agents[id]["states"][state], move_toward, REWARD)

def create_agent(id:int):
    agents[id] = {}
    agents[id]["states"] = {}
    agents[id]["total_survival"] = 0.0
    agents[id]["avg_survival"] = 0.0
    agents[id]["max_survival"] = 0.0
    agents[id]["num_iters"] = 0
    agents[id]["packets_received"] = 0

def insert_hyp(state:str, hyp:float, id:int):
    if not id in agents:
        create_agent(id)
    agents[id]["states"][state] = hyp

def update_hyp(state:str, time_alive:float, jumped:bool, id:int):
    if not id in agents:
        create_agent(id)
    if not state in agents[id]["states"]:
        insert_hyp(state, 0.5, id)
    positive_reward = (time_alive - REWARD_BUFFER) > agents[id]["avg_survival"]
    #update hypothesis
    if positive_reward:
        reward(state, jumped, id)
    else:
        punish(state, jumped, id)

def sort_agents_states():
    for id in agents.keys():
        sort_agent_states(id)

def sort_agent_states(id:int):
    agents[id]["states"] = dict(sorted(agents[id]["states"].items()))

# def send_all_agents():
#     url = "http://localhost:5000/update_agents"
#     sort_agents_states()
#     data = agents
#     x = requests.post(url, json = data)
#     print(str(x))

def send_updated_agent(id:int):
    url = "http://localhost:5000/update_agents"
    sort_agent_states(id)
    data = {id : agents[id]}
    x = requests.post(url, json = data)
    # print(x.text)
    if x.text == "KILL":
        print("received kill request for id:" + str(id))
        kill_requests.append(id)

def send_dead_agent_id(id:int):
    url = "http://localhost:5000/delete_agent"
    data = {"id":id}
    x = requests.delete(url, json = data)
    # print(x.text)

def print_stats(id):
    print("total survival for " + str(id) + ": " + str(agents[id]["total_survival"]))
    print("average survival for " + str(id) + ": " + str(agents[id]["avg_survival"]))
    print("max survival for " + str(id) + ": " + str(agents[id]["avg_survival"]))
    print("number of iterations for " + str(id) + ": " + str(agents[id]["num_iters"]))
    print("packets rcv'd from " + str(id) + ": " + str(agents[id]["packets_received"]))
    print("total packets received from all: " + str(packets_received))

class MyUDPHandler(socketserver.BaseRequestHandler):
    def handle(self):
        global packets_received
        # global num_iters
        # global total_survival
        # global avg_survival
        data = self.request[0].strip()
        socket = self.request[1]
        temp_arr = data.decode("utf-8").split(",")
        if temp_arr[0] == "0": # data structure: ['0',state,hypothesis,id]
            packets_received += 1
            state = temp_arr[1]
            hypothesis = float(temp_arr[2])
            id = int(temp_arr[3])
            insert_hyp(state, hypothesis, id)
            agents[id]["packets_received"] = agents[id]["packets_received"] + 1
        elif temp_arr[0] == "1": # data structure: ['1',state,time_lived,jumped,id]
            packets_received += 1
            temp_arr = data.decode().split(",")
            state = temp_arr[1]
            time_alive = float(temp_arr[2])
            jumped = temp_arr[3]=="true"
            id = int(temp_arr[4])
            update_hyp(state, time_alive, jumped, id)
            agents[id]["packets_received"] = agents[id]["packets_received"] + 1
            if id in kill_requests:
                kill_requests.remove(id)
                socket.sendto(("_2," + str(id)).encode("utf-8"), self.client_address)
            else:
                socket.sendto(("_1," + state + "," + str(agents[id]["states"].get(state))).encode("utf-8"), self.client_address)
        elif temp_arr[0] == "2": # data structure: ['2',survive_time,id]
            packets_received += 1
            temp_arr = data.decode("utf-8").split(",")
            survive_time = float(temp_arr[1])
            id = int(temp_arr[2])
            if id in agents:
                agents[id]["num_iters"] = agents[id]["num_iters"] + 1
                agents[id]["total_survival"] = agents[id]["total_survival"] + survive_time
                if survive_time > agents[id]["max_survival"]:
                    agents[id]["max_survival"] = survive_time
                agents[id]["avg_survival"] = agents[id]["total_survival"]/float(agents[id]["num_iters"])
                agents[id]["packets_received"] = agents[id]["packets_received"] + 1
                # print_stats(id)
            send_updated_agent(id)
        elif temp_arr[0] == "3": #data structure: ['3',id_of_who_died]
            temp_arr = data.decode("utf-8").split(",")
            id = int(temp_arr[1])
            send_dead_agent_id(id)


if __name__ == "__main__":
    HOST, PORT = "localhost", 9999
    with socketserver.UDPServer((HOST, PORT), MyUDPHandler) as server:
        server.serve_forever()
