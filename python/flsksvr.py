# Importing flask module in the project is mandatory
# An object of Flask class is our WSGI application.
from flask import Flask, request

# Enabling templates
from flask import render_template

import random, json

# Flask constructor takes the name of 
# current module (__name__) as argument.
app = Flask(__name__)

props_dict = {
	"state_off_class" : "grow bg-slate-900",
	"state_on_class" : "grow bg-blue-500/95",
	"hypothesis_slider_class" : "h-3 bg-amber-500/95",
	"agents" : {}
}

kill_requests = []

def remove_agent(id:int):
	if id in props_dict["agents"]:
		del props_dict["agents"][id]

# {
	# 1 : {
	# 	"states" : {
	# 		"110100101101" : 0.93636712,
	# 		"000000101000" : 0.112,
	# 	},
	# 	"total_survival" : 50.345,
	# 	"avg_survival" : 4.56,
	# 	"num_iters" : 145,
	# },
	# 2 : {
	# 	"states" : {
	# 		"011111001101" : 0.3222,
	# 		"111111111111" : 0.72,
	# 	},
	# 	"total_survival" : 34.5,
	# 	"avg_survival" : 9.7,
	# 	"num_iters" : 56,
	# }
# }
# def sort_agent_states():
# 	for i in range(len(props_dict.get("agents"))):
# 		props_dict["agents"][i] = dict(sorted(props_dict["agents"][i].items()))
	# for i in range(len(props_dict.get("agents"))):
	# 	print (props_dict["agents"][i])

# The route() function of the Flask class is a decorator, 
# which tells the application which URL should call 
# the associated function.
@app.route("/")
def home():
	header_text = "Dashboard"
	return render_template("body.html", message=header_text, props=props_dict)

@app.route("/update_agents", methods = ["POST"])
def update_agents():
	agents = request.get_json()
	for id_key in agents.keys():
		int_id = int(id_key) #not sure why this is necessary
		if int_id in kill_requests:
			kill_requests.remove(int_id)
			remove_agent(id)
			data = "KILL"
			return data
		else:
			props_dict["agents"][int_id] = agents[id_key]
			return "OK"

@app.route("/kill_agent_request", methods = ["POST"])
def request_kill_agent():
	id = int(request.args.get('id'))
	kill_requests.append(id)
	#todo: replace with different ajax logic or "disabled/dead" flag on agent
	remove_agent(id)
	return "OK"

@app.route("/delete_agent", methods = ["DELETE"])
def delete_agent():
	json_data = request.get_json()
	id = json_data["id"]
	if id in props_dict["agents"]:
		del props_dict["agents"][id]
	return "OK"

# main driver function
if __name__ == "__main__":

	# run() method of Flask class runs the application 
	# on the local development server.
	app.run()

