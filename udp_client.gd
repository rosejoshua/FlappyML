extends Node

var client = PacketPeerUDP.new()
var messages = []

func _ready():
	client.connect_to_host("127.0.0.1", 9999)
#	client.put_packet("connect".to_utf8_buffer())
	#client.get_available_packet_count() > 0:
	#client.get_packet().get_string_from_utf8()
	
func send_msg(msg:String):
	client.put_packet(msg.to_utf8_buffer())
	
func get_msg() -> String:
	return messages.pop_front()

func msg_waiting():
	return messages.size() > 0

func _process(delta):
	while client.get_available_packet_count() > 0:
		messages.push_back(client.get_packet().get_string_from_utf8())
