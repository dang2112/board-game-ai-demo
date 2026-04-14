extends Node
#multiplayer is the underlying godot multiplayer API available on every node.
#this manager interacts with it
#it provides host/join functionality for a 2 player enet session
#appropriate signals are provided
#basic message transports: to server, to peer, broadcast

signal hosting_started(port: int)
signal hosting_failed(error_code: int)
signal connected_to_server()
signal connection_failed()
signal disconnected_from_server()
signal peer_connected_to_match(peer_id: int)
signal peer_disconnected_from_match(peer_id: int)
signal network_message_received(message: Dictionary, from_peer: int)

const DEFAULT_PORT := 24567
const DEFAULT_MAX_CLIENTS := 2

var peer: ENetMultiplayerPeer = null
var listen_port: int = DEFAULT_PORT

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_match(port: int = DEFAULT_PORT, max_clients: int = DEFAULT_MAX_CLIENTS) -> bool:
	stop_networking()
	var new_peer := ENetMultiplayerPeer.new()
	var error := new_peer.create_server(port, max_clients)
	if error != OK:
		hosting_failed.emit(error)
		return false

	peer = new_peer
	listen_port = port
	multiplayer.multiplayer_peer = peer
	hosting_started.emit(port)
	return true

func join_match(host: String, port: int = DEFAULT_PORT) -> bool:
	stop_networking()
	var new_peer := ENetMultiplayerPeer.new()
	var error := new_peer.create_client(host, port)
	if error != OK:
		connection_failed.emit()
		return false

	peer = new_peer
	listen_port = port
	multiplayer.multiplayer_peer = peer
	return true

func stop_networking() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	peer = null

func is_hosting() -> bool:
	return peer != null and multiplayer.is_server()

func is_multiplayerconnected() -> bool:
	return multiplayer.multiplayer_peer != null

func get_local_peer_id() -> int:
	return multiplayer.get_unique_id()

func get_connected_peer_ids() -> Array:
	return multiplayer.get_peers()

func send_message_to_server(message: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		network_message_received.emit(message, get_local_peer_id())
		return
	_receive_message.rpc_id(1, message)

func broadcast_message(message: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		_receive_message.rpc(message)
		network_message_received.emit(message, get_local_peer_id())

func send_message_to_peer(peer_id: int, message: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	_receive_message.rpc_id(peer_id, message)

@rpc("any_peer", "reliable")
func _receive_message(message: Dictionary) -> void:
	network_message_received.emit(message, multiplayer.get_remote_sender_id())

func _on_peer_connected(peer_id: int) -> void:
	peer_connected_to_match.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	peer_disconnected_from_match.emit(peer_id)

func _on_connected_to_server() -> void:
	connected_to_server.emit()

func _on_connection_failed() -> void:
	connection_failed.emit()
	stop_networking()

func _on_server_disconnected() -> void:
	disconnected_from_server.emit()
	stop_networking()
