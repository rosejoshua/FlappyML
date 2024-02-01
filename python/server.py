import socketserver

REWARD = 0.08
PUNISHMENT = 0.07
REWARD_BUFFER = 0.02
states_and_outcomes:dict = {}
total_survival = 0.0
avg_survival = 0.0
num_iters = 0
packets_received = 0

def lerpf(frm:float, to:float, dlt:float) -> float:
    return (frm * (1.0 - dlt)) + (to * dlt)

def punish(state:str, jumped:bool):
    if jumped:
        move_toward = 0.0
    else:
        move_toward = 1.0
    states_and_outcomes[state] = lerpf(states_and_outcomes.get(state), move_toward, PUNISHMENT)

def reward(state:str, jumped:bool):
    if jumped:
        move_toward = 1.0
    else:
        move_toward = 0.0
    states_and_outcomes[state] = lerpf(states_and_outcomes.get(state), move_toward, REWARD)

def insert_hyp(state:str, hyp:float):
    states_and_outcomes[state] = hyp

def update_hyp(state, time_alive, jumped):
    positive_reward = (time_alive - REWARD_BUFFER) > avg_survival
    #update hypothesis
    if positive_reward:
        reward(state, jumped)
    else:
        punish(state, jumped)

class MyUDPHandler(socketserver.BaseRequestHandler):
    def handle(self):
        global packets_received
        global num_iters
        global total_survival
        global avg_survival
        data = self.request[0].strip()
        socket = self.request[1]
        temp_arr = data.decode("utf-8").split(",")
        if temp_arr[0] == "0": # data structure: ['0',state,hypothesis]
            packets_received += 1
            state = temp_arr[1]
            hypothesis = temp_arr[2]
            insert_hyp(state, float(hypothesis))
        elif temp_arr[0] == "1": # data structure: ['1',state,time_lived,jumped]
            packets_received += 1
            temp_arr = data.decode().split(",")
            state = temp_arr[1]
            time_alive = float(temp_arr[2])
            jumped = temp_arr[3]=="true"
            update_hyp(state, time_alive, jumped)
            socket.sendto(("_," + state + "," + str(states_and_outcomes.get(state))).encode("utf-8"), self.client_address)
        elif temp_arr[0] == "2": # data structure: ['2',survive_time]
            packets_received += 1
            temp_arr = data.decode("utf-8").split(",")
            num_iters += 1
            total_survival += float(temp_arr[1])
            avg_survival = total_survival/float(num_iters)
            print("packets rcv'd: " + str(packets_received))
            print("total survival: " + str(total_survival))
            print("avg survival: " + str(avg_survival))


if __name__ == "__main__":
    HOST, PORT = "localhost", 9999
    with socketserver.UDPServer((HOST, PORT), MyUDPHandler) as server:
        server.serve_forever()
