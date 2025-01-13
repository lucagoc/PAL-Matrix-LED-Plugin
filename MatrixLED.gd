extends Node

# Parameters
var websocket_url = "ws://localhost:4444"																# The URL of the WebSocket server.
var fallback_animation_path = Settings.get_setting("General", "plugins_folder_path") + "fallback.gif"	# The path to the fallback animation.
var gif_path = "led.gif"																				# The path to the GIF file of PAPs.

var socket := WebSocketPeer.new()

# When a game is launched, we will display the game's GIF on the LED matrix.
func _on_game_launched(id: int):
	var img_path = GameList.GAME_LIST[id].path + gif_path
	print(img_path)
	set_animation(img_path)

# When a game is selected, we will display the game's GIF on the LED matrix.
func _on_game_selected(id: int):
	var img_path = GameList.GAME_LIST[id].path + gif_path
	print(img_path)
	set_animation(img_path)

# Convert a GIF file to a hexadecimal string.
func _gif_to_hexa(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var data = file.get_buffer(file.get_length())
		file.close()
		return data.hex_encode()
	else:
		file = FileAccess.open(fallback_animation_path, FileAccess.READ)
		var data = file.get_buffer(file.get_length())
		file.close()
		return data.hex_encode()

# Called when the node enters the scene tree for the first time.
func _ready():
	print("[LED] Plugin loaded successfully.")

	BusEvent.connect("GAME_LAUNCHED", _on_game_launched)
	BusEvent.connect("GAME_SELECTED", _on_game_selected)

	if socket.connect_to_url(websocket_url) != OK:
		printerr("[LED] Could not connect.")
		set_process(false)
	else:
		print("[LED] Connected")

# Called every frame.
func _process(_delta):
	socket.poll()

	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			print("[DEBUG][LED] RECEIVED: ", socket.get_packet().get_string_from_ascii())

# Called when the node is removed from the scene tree.
func _exit_tree():
	socket.close()

# Send data to the server.
func _send_data(data):
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		printerr("[LED] Could not send data, socket not open.")
	else:
		# Send JSON data to the server (command + parameter)
		socket.send_text(JSON.stringify(data))

# Send a command to the server to set the text on the LED matrix.
func set_text(string):
	var data = {
		"command": "set_text",
		"parameter": string
	}
	
	_send_data(data)

# Send a command to the server to set the animation on the LED matrix.
func set_animation(path):
	var data = {
		"command": "set_animation",
		"parameter": _gif_to_hexa(path)
	}
	
	_send_data(data)
