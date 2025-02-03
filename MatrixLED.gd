extends Node

# Parameters
var websocket_url = "ws://localhost:4444"  # WebSocket server URL.
var fallback_animation_path = Settings.get_setting("General", "plugins_folder_path") + "fallback.gif"
var ecomode_animation_path = Settings.get_setting("General", "plugins_folder_path") + "ecomode.gif"
var gif_path = "led.gif"
var buffer_refresh_rate = 0.7  # Time between each buffer refresh
var brightness = 50  # Brightness of the LED

var socket := WebSocketPeer.new()
var last_command = null  # Buffer for the last command
var is_stopped = false

func send_animation_or_text(path, game_name):
	if is_stopped and game_name != "Eco mode":
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		# L'image existe, on l'envoie en hexadécimal
		var data = file.get_buffer(file.get_length())
		file.close()
		last_command = {
			"command": "send_animation",
			"params": [data.hex_encode()]
		}
	else:
		# L'image n'existe pas, on envoie le nom du jeu en texte
		send_text(game_name)

func _on_game_launched(id: int):
	send_animation_or_text(GameList.GAME_LIST[id].path + gif_path, GameList.GAME_LIST[id].name)

func _on_start_screensaver():
	send_animation_or_text(fallback_animation_path, "Screensaver")
	is_stopped = true

func _on_stop_screensaver():
	is_stopped = false
	send_animation_or_text(fallback_animation_path, "Screensaver")

func _on_ecomode_activated():
	send_animation_or_text(ecomode_animation_path, "Eco mode")
	is_stopped = true

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

func _on_game_list_loaded():
	send_animation_or_text(fallback_animation_path, "Screensaver")

func _on_game_exited(id: int):
	send_animation_or_text(fallback_animation_path, "Screensaver")

func _ready():
	print("[LED] Plugin loaded successfully.")
	BusEvent.connect("GAME_LAUNCHED", _on_game_launched)
	BusEvent.connect("GAME_EXITED", _on_game_exited)
	BusEvent.connect("START_SCREENSAVER", _on_start_screensaver)
	BusEvent.connect("STOP_SCREENSAVER", _on_stop_screensaver)
	BusEvent.connect("ECOMODE_ACTIVATED", _on_ecomode_activated)
	BusEvent.connect("GAME_LIST_LOADED", _on_game_list_loaded)

	# Configure buffer to send data
	var send_timer = Timer.new()
	send_timer.wait_time = buffer_refresh_rate
	send_timer.one_shot = false
	send_timer.connect("timeout", _on_send_timer_timeout)
	add_child(send_timer)

	if socket.connect_to_url(websocket_url) != OK:
		printerr("[LED] Could not connect.")
		send_timer.stop()
		set_process(false)
	else:
		print("[LED] Connected")
		send_clear()
		send_timer.start()

func _process(delta):
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			print("[DEBUG][LED] RECEIVED: ", socket.get_packet().get_string_from_ascii())

func _exit_tree():
	socket.close()

func _on_send_timer_timeout():
	if last_command:
		_send_data(last_command)
		last_command = null

func _send_data(data):
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		printerr("[LED] Could not send data, socket not open.")
	else:
		#print("[DEBUG][LED] SENDING: ", data)
		socket.send_text(JSON.stringify(data))

# Buffer the command and start the timer if not running
func send_text(string):
	last_command = {
		"command": "send_text",
		"params": [string, "rainbow_mode=3", "speed=80", "animation=1"]
	}

func send_animation(path):
	last_command = {
		"command": "send_animation",
		"params": [_gif_to_hexa(path)]
	}

func send_clear():
	last_command = {
		"command": "clear",
		"params": []
	}

func send_brightness(value):
	last_command = {
		"command": "set_brightness",
		"params": [value]
	}
