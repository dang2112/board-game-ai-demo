extends Control

const TILE_SIZE := 100
const HUMAN_TEAM := 0
const AI_TEAM := 1
const UI_GAP := 12
const UI_PADDING := 12

@export var TEAM0_POINTS := 20
@export var TEAM1_POINTS := 20
@export var VP_COND := 2

@onready var UnitManager = $UnitManager
@onready var MapManager = $MapManager
@onready var AiController = $AiController
@onready var NetworkManager = $NetworkManager

@onready var HUDPanel = $UI/HUDPanel
@onready var TurnLabel = $UI/HUDPanel/MarginContainer/VBoxContainer/TurnLabel
@onready var SelectionLabel = $UI/HUDPanel/MarginContainer/VBoxContainer/SelectionLabel
@onready var APLabel = $UI/HUDPanel/MarginContainer/VBoxContainer/APLabel
@onready var ModeLabel = $UI/HUDPanel/MarginContainer/VBoxContainer/ModeLabel
@onready var StatusLabel = $UI/HUDPanel/MarginContainer/VBoxContainer/StatusLabel
@onready var AbilityTitle = $UI/HUDPanel/MarginContainer/VBoxContainer/AbilityTitle
@onready var AbilityButtons = $UI/HUDPanel/MarginContainer/VBoxContainer/AbilityButtons
@onready var EndTurnButton = $UI/HUDPanel/MarginContainer/VBoxContainer/ButtonRow/EndTurnButton
@onready var PauseButton: TextureButton = $UI/PauseButton
@onready var MultiplayerPanel: PanelContainer = $UI/MultiplayerPanel
@onready var HostInput: LineEdit = $UI/MultiplayerPanel/MarginContainer/VBoxContainer/HostInput
@onready var PortInput: LineEdit = $UI/MultiplayerPanel/MarginContainer/VBoxContainer/PortInput
@onready var HostButton: Button = $UI/MultiplayerPanel/MarginContainer/VBoxContainer/ButtonRow/HostButton
@onready var JoinButton: Button = $UI/MultiplayerPanel/MarginContainer/VBoxContainer/ButtonRow/JoinButton
@onready var DisconnectButton: Button = $UI/MultiplayerPanel/MarginContainer/VBoxContainer/ButtonRow/DisconnectButton
@onready var MultiplayerInfoLabel: Label = $UI/MultiplayerPanel/MarginContainer/VBoxContainer/MultiplayerInfoLabel
@onready var PauseOverlay = $UI/PauseOverlay
@onready var ResumeButton: TextureButton = $UI/PauseOverlay/CenterContainer/ResumeButton
@onready var ActionLogPanel: PanelContainer = $UI/ActionLogPanel
@onready var ActionLogLabel: Label = $UI/ActionLogPanel/MarginContainer/ActionLogLabel
@onready var VictoryOverlay = $UI/VictoryOverlay
@onready var VictoryLabel: Label = $UI/VictoryOverlay/CenterContainer/VictoryPanel/MarginContainer/VBoxContainer/VictoryLabel
@onready var VictorySubtitle: Label = $UI/VictoryOverlay/CenterContainer/VictoryPanel/MarginContainer/VBoxContainer/VictorySubtitle
@onready var PlayAgainButton: Button = $UI/VictoryOverlay/CenterContainer/VictoryPanel/MarginContainer/VBoxContainer/PlayAgainButton

const PAUSE_ICON_PATH := "res://assets/pause.png"
const RESUME_ICON_PATH := "res://assets/resume.png"

var unit_pool = [
	{"scene": "res://scenes/rifleman.tscn", "cost": 3},
	{"scene": "res://scenes/sniper.tscn", "cost": 5},
	{"scene": "res://scenes/scout.tscn", "cost": 2},
	{"scene": "res://scenes/rusher.tscn", "cost": 7}
]

var current_team = HUMAN_TEAM
var team_no = 2
var defeated_teams = []
var selected_unit: Unit = null
var selected_ability: Ability = null
var status_message := ""
var board_origin: Vector2 = Vector2.ZERO
var team_vp = []
var team_ap = []
var vt = []
var team_won: int = -2
var game_over := false
var action_log_tween: Tween = null
var map_visual_scale: float = 1.0
var local_team := HUMAN_TEAM
var match_state := MatchState.new()
var multiplayer_enabled := false
var multiplayer_pending := false
var remote_peer_id := -1

func generate_army(points: int, team: int) -> void:
	var remaining = points
	var available_choices: Array = []
	for unit in unit_pool:
		if unit["cost"] <= remaining:
			available_choices.append(unit)
	while not available_choices.is_empty():
		var choice = available_choices.pick_random()
		var pos = MapManager.get_random_spawn(team, UnitManager)
		if pos == Vector2i(-1, -1):
			break
		UnitManager.spawn_unit(choice["scene"], pos, team)
		remaining -= choice["cost"]
		available_choices.clear()
		for unit in unit_pool:
			if unit["cost"] <= remaining:
				available_choices.append(unit)

func _ready() -> void:
	HUDPanel.process_mode = Node.PROCESS_MODE_ALWAYS
	MultiplayerPanel.process_mode = Node.PROCESS_MODE_ALWAYS
	PauseButton.process_mode = Node.PROCESS_MODE_ALWAYS
	PauseOverlay.process_mode = Node.PROCESS_MODE_ALWAYS
	ResumeButton.process_mode = Node.PROCESS_MODE_ALWAYS
	ActionLogPanel.process_mode = Node.PROCESS_MODE_ALWAYS
	VictoryOverlay.process_mode = Node.PROCESS_MODE_ALWAYS
	PlayAgainButton.process_mode = Node.PROCESS_MODE_ALWAYS
	PauseButton.texture_normal = _load_icon(PAUSE_ICON_PATH)
	ResumeButton.texture_normal = _load_icon(RESUME_ICON_PATH)
	PauseButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ResumeButton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	EndTurnButton.pressed.connect(_on_end_turn_button_pressed)
	HostButton.pressed.connect(_on_host_button_pressed)
	JoinButton.pressed.connect(_on_join_button_pressed)
	DisconnectButton.pressed.connect(_on_disconnect_button_pressed)
	PauseButton.pressed.connect(_on_pause_button_pressed)
	ResumeButton.pressed.connect(_on_pause_button_pressed)
	PlayAgainButton.pressed.connect(_on_play_again_button_pressed)
	PauseButton.mouse_entered.connect(_on_pause_button_mouse_entered)
	PauseButton.mouse_exited.connect(_on_pause_button_mouse_exited)
	ResumeButton.mouse_entered.connect(_on_resume_button_mouse_entered)
	ResumeButton.mouse_exited.connect(_on_resume_button_mouse_exited)
	get_viewport().size_changed.connect(_layout_ui)
	NetworkManager.hosting_started.connect(_on_hosting_started)
	NetworkManager.hosting_failed.connect(_on_hosting_failed)
	NetworkManager.connected_to_server.connect(_on_connected_to_server)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.disconnected_from_server.connect(_on_disconnected_from_server)
	NetworkManager.peer_connected_to_match.connect(_on_peer_connected_to_match)
	NetworkManager.peer_disconnected_from_match.connect(_on_peer_disconnected_from_match)
	NetworkManager.network_message_received.connect(_on_network_message_received)
	MapManager.load_map("res://resources/map_big.gd")
	_layout_ui()
	generate_army(TEAM0_POINTS, HUMAN_TEAM)
	generate_army(TEAM1_POINTS, AI_TEAM)
	vt = MapManager.get_all_victory_tiles()
	match_state.reset(team_no, HUMAN_TEAM, "Blue units are yours. Click a Blue unit, then choose an ability.")
	match_state.units = UnitManager.units
	_sync_from_match_state()
	_sync_victory_overlay()
	_update_multiplayer_panel()
	start_turn()

func _layout_ui() -> void:
	if MapManager == null or HUDPanel == null or PauseButton == null:
		return
	if MapManager.grid_size == Vector2i.ZERO:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var base_map_size: Vector2 = Vector2(MapManager.grid_size.x * TILE_SIZE, MapManager.grid_size.y * TILE_SIZE)
	var panel_size: Vector2 = HUDPanel.custom_minimum_size
	var available_map_width: float = maxf(viewport_size.x - panel_size.x - UI_GAP - float(UI_PADDING) * 2.0, 1.0)
	var available_map_height: float = maxf(viewport_size.y - float(UI_PADDING) * 2.0, 1.0)
	map_visual_scale = minf(1.0, minf(available_map_width / base_map_size.x, available_map_height / base_map_size.y))
	var map_size: Vector2 = base_map_size * map_visual_scale
	var total_width: float = map_size.x + UI_GAP + panel_size.x
	var origin_x: float = maxf((viewport_size.x - total_width) * 0.5, float(UI_PADDING))
	var origin_y: float = maxf((viewport_size.y - map_size.y) * 0.5, float(UI_PADDING))
	var map_origin: Vector2 = Vector2(origin_x, origin_y)
	MapManager.position = map_origin
	UnitManager.position = map_origin
	MapManager.scale = Vector2.ONE * map_visual_scale
	UnitManager.scale = Vector2.ONE * map_visual_scale
	HUDPanel.position = Vector2(origin_x + map_size.x + UI_GAP, origin_y)
	MultiplayerPanel.position = Vector2(HUDPanel.position.x, HUDPanel.position.y + HUDPanel.get_combined_minimum_size().y + UI_GAP)
	PauseButton.position = MultiplayerPanel.position + Vector2(0.0, MultiplayerPanel.get_combined_minimum_size().y + UI_GAP)
	if ActionLogPanel != null and ActionLogPanel.visible:
		ActionLogPanel.position = map_origin + Vector2(16, 16)
		ActionLogPanel.size = ActionLogPanel.get_combined_minimum_size()
	board_origin = map_origin
	PauseOverlay.position = Vector2.ZERO
	if VictoryOverlay != null:
		VictoryOverlay.position = Vector2.ZERO

func show_action_log(message: String, board_pos: Vector2i) -> void:
	if ActionLogPanel == null or ActionLogLabel == null:
		return
	ActionLogLabel.text = message
	ActionLogPanel.visible = true
	ActionLogPanel.modulate = Color(1, 1, 1, 1)
	ActionLogPanel.z_index = 1000
	ActionLogPanel.size = ActionLogPanel.get_combined_minimum_size()
	var scaled_tile_size: float = float(TILE_SIZE) * map_visual_scale
	var map_size: Vector2 = Vector2(MapManager.grid_size.x * scaled_tile_size, MapManager.grid_size.y * scaled_tile_size)
	var desired_position: Vector2 = board_origin + Vector2(board_pos.x * scaled_tile_size + 12.0, board_pos.y * scaled_tile_size + 12.0)
	var max_x: float = board_origin.x + map_size.x - ActionLogPanel.size.x
	var max_y: float = board_origin.y + map_size.y - ActionLogPanel.size.y
	ActionLogPanel.position.x = clampf(desired_position.x, board_origin.x, max_x)
	ActionLogPanel.position.y = clampf(desired_position.y, board_origin.y, max_y)
	if action_log_tween != null and is_instance_valid(action_log_tween):
		action_log_tween.kill()
	action_log_tween = create_tween()
	action_log_tween.tween_interval(2.3)
	action_log_tween.tween_property(ActionLogPanel, "modulate", Color(1, 1, 1, 0), 0.35)
	action_log_tween.tween_callback(_hide_action_log)

func announce_action(message: String, board_pos: Vector2i) -> void:
	status_message = message
	show_action_log(message, board_pos)
	_update_ui()

func _hide_action_log() -> void:
	if ActionLogPanel == null:
		return
	ActionLogPanel.visible = false
	ActionLogPanel.modulate = Color(1, 1, 1, 1)

func _load_icon(path: String) -> Texture2D:
	var image: Image = Image.load_from_file(path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)

func _set_button_scale(button: TextureButton, target_scale: Vector2) -> void:
	if button == null:
		return
	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.12)

func _on_pause_button_mouse_entered() -> void:
	_set_button_scale(PauseButton, Vector2(1.06, 1.06))

func _on_pause_button_mouse_exited() -> void:
	_set_button_scale(PauseButton, Vector2(1.0, 1.0))

func _on_resume_button_mouse_entered() -> void:
	_set_button_scale(ResumeButton, Vector2(1.06, 1.06))

func _on_resume_button_mouse_exited() -> void:
	_set_button_scale(ResumeButton, Vector2(1.0, 1.0))

func start_turn() -> void:
	print("=== START_TURN CALLED ===")
	print("current_team before MatchRules: ", current_team)
	print("team_ap before MatchRules: ", team_ap)
	MatchRules.start_turn(self, match_state)
	print("current_team after MatchRules: ", current_team)
	print("match_state.team_ap after MatchRules: ", match_state.team_ap)
	print("team_ap after MatchRules (before sync): ", team_ap)
	var current_units = UnitManager.get_units_for_team(current_team)
	print("Units for team ", current_team, ": ", current_units.size())
	_sync_from_match_state()
	print("team_ap after sync: ", team_ap)
	_sync_victory_overlay()
	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()
	if current_team == AI_TEAM and not get_tree().paused and not game_over and not _is_online_mode():
		AiController.call_deferred("take_turn")

func end_turn() -> void:
	MatchRules.end_turn(self, match_state, vt)
	_sync_from_match_state()
	_sync_victory_overlay()
	if not game_over:
		start_turn()
		return
	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()

func _input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				save_board_state()
				status_message = "Game saved."
				_sync_to_match_state()
				_update_ui()
			KEY_F9:
				if load_board_state():
					status_message = "Game loaded."
				else:
					status_message = "Load failed."
				_sync_to_match_state()
				_update_ui()

func _unhandled_input(event) -> void:
	if selected_unit != null and _get_team_action_points(current_team) <= 0:
		return
	if game_over or get_tree().paused or multiplayer_pending:
		return
	if _is_online_mode():
		var can_play := (current_team == local_team) or (current_team == 0 and local_team == 2) or (current_team == 2 and local_team == 0)
		if not can_play:
			return
	else:
		if current_team != local_team:
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = event.position - board_origin
		if local_pos.x < 0 or local_pos.y < 0:
			return
		var scaled_tile_size: float = float(TILE_SIZE) * map_visual_scale
		if local_pos.x >= float(MapManager.grid_size.x) * scaled_tile_size or local_pos.y >= float(MapManager.grid_size.y) * scaled_tile_size:
			return
		var grid_pos := Vector2i(int(floor(local_pos.x / scaled_tile_size)), int(floor(local_pos.y / scaled_tile_size)))
		handle_board_click(grid_pos)

func handle_board_click(grid_pos: Vector2i) -> void:
	var clicked_unit = UnitManager.get_unit_at(grid_pos)
	var is_my_unit := false
	if clicked_unit != null:
		if _is_online_mode():
			is_my_unit = (clicked_unit.team == current_team) or (current_team == 0 and local_team == 2 and clicked_unit.team == 0) or (current_team == 2 and local_team == 0 and clicked_unit.team == 2)
		else:
			is_my_unit = clicked_unit.team == current_team
	
	if selected_unit == null:
		if clicked_unit != null and is_my_unit and clicked_unit.can_act():
			select_unit(clicked_unit)
		return
	
	if clicked_unit != null and is_my_unit and clicked_unit.can_act():
		select_unit(clicked_unit)
		return
	
	if selected_ability == null:
		status_message = "Choose an ability first."
		_update_ui()
		return
	var ability_index := selected_unit.abilities.find(selected_ability)
	if ability_index == -1:
		status_message = "Selected ability is unavailable."
		_update_ui()
		return
	_submit_player_action(MatchRules.make_action(selected_unit.position_on_grid, ability_index, grid_pos))

func apply_match_action(action: Dictionary) -> Dictionary:
	var result = MatchRules.apply_action(self, match_state, action)
	_sync_from_match_state()
	_sync_victory_overlay()
	if not bool(result.get("ok", false)):
		status_message = String(result.get("reason", "Action failed."))
		_sync_to_match_state()
		_refresh_ability_panel()
		_refresh_highlights()
		_update_ui()
		return result
	if result.has("message") and result.has("board_pos"):
		announce_action(String(result["message"]), result["board_pos"])
	if bool(result.get("end_turn", false)):
		if _is_online_mode():
			_sync_to_match_state()
			_broadcast_state_sync()
			return result
		start_turn()
		return result
	selected_unit = null
	selected_ability = null
	_sync_to_match_state()
	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()
	if bool(result.get("auto_end_turn", false)) and not game_over:
		if _is_online_mode():
			_broadcast_state_sync()
			return result
		end_turn()
	return result

func get_legal_actions_for_team(team: int) -> Array:
	return MatchRules.get_legal_actions(self, match_state, team)

func _submit_player_action(action: Dictionary) -> void:
	if multiplayer_pending:
		return
	if _is_online_mode() and not NetworkManager.is_hosting():
		status_message = "Sending action to host..."
		_update_ui()
		NetworkManager.send_message_to_server({
			"type": "submit_action",
			"action": action,
		})
		return

	var result = apply_match_action(action)
	if _is_online_mode() and bool(result.get("ok", false)):
		_broadcast_state_sync()

func host_online_match(port: int = NetworkManager.DEFAULT_PORT) -> bool:
	var success: bool = NetworkManager.host_match(port)
	if success:
		multiplayer_pending = true
		multiplayer_enabled = false
		local_team = HUMAN_TEAM
		team_no = 3
		remote_peer_id = -1
		status_message = "Hosting match. Waiting for another player..."
		_update_multiplayer_panel()
		_update_ui()
	return success

func join_online_match(host: String, port: int = NetworkManager.DEFAULT_PORT) -> bool:
	var success: bool = NetworkManager.join_match(host, port)
	if success:
		multiplayer_pending = true
		multiplayer_enabled = false
		local_team = 2
		status_message = "Connecting to host..."
		_update_multiplayer_panel()
		_update_ui()
	return success

func stop_online_match() -> void:
	NetworkManager.stop_networking()
	multiplayer_enabled = false
	multiplayer_pending = false
	remote_peer_id = -1
	local_team = HUMAN_TEAM
	_update_multiplayer_panel()

func select_unit(unit: Unit) -> void:
	if unit == null or not unit.can_act():
		return
	if selected_unit == unit:
		selected_unit = null
		selected_ability = null
		status_message = "Unit deselected."
	else:
		selected_unit = unit
		selected_ability = unit.abilities[0] if unit.abilities.size() > 0 else null
		status_message = "%s selected." % unit.display_name
	_sync_to_match_state()
	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()

func select_ability_by_ability(ability: Ability) -> void:
	if selected_unit == null:
		return
	if ability == null or not is_instance_valid(ability):
		return
	selected_ability = ability
	status_message = "%s ready. Click a valid target." % selected_ability.get_display_name()
	_sync_to_match_state()
	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()

func _refresh_ability_panel() -> void:
	for child in AbilityButtons.get_children():
		child.queue_free()
	if selected_unit == null:
		var prompt = Label.new()
		prompt.text = "Select a unit to see abilities."
		AbilityButtons.add_child(prompt)
		AbilityTitle.text = "Abilities"
		return
	AbilityTitle.text = "%s abilities" % selected_unit.display_name
	for i in range(selected_unit.abilities.size()):
		var ability = selected_unit.abilities[i]
		var button = Button.new()
		button.text = ability.get_display_name()
		if ability == selected_ability:
			button.text = "> %s" % button.text
		button.pressed.connect(select_ability_by_ability.bind(ability))
		AbilityButtons.add_child(button)
	if selected_unit.abilities.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No abilities available."
		AbilityButtons.add_child(empty_label)

func _refresh_highlights() -> void:
	if MapManager == null:
		return
	for tile in MapManager.tiles.values():
		tile.set_highlight(Tile.HIGHLIGHT_NONE)
	if selected_unit == null:
		return
	var selected_tile = MapManager.get_tile(selected_unit.position_on_grid)
	if selected_tile != null:
		selected_tile.set_highlight(Tile.HIGHLIGHT_SELECTED)
	if selected_ability == null:
		return
	var valid_targets = selected_ability.get_valid_targets(selected_unit, MapManager, UnitManager, _get_team_action_points(current_team))
	for target_pos in valid_targets:
		var target_tile = MapManager.get_tile(target_pos)
		if target_tile == null:
			continue
		match selected_ability.get_target_mode():
			Ability.TARGET_TILE:
				target_tile.set_highlight(Tile.HIGHLIGHT_MOVE)
			Ability.TARGET_UNIT:
				target_tile.set_highlight(Tile.HIGHLIGHT_TARGET)

func _update_ui() -> void:
	TurnLabel.text = "Turn: %s" % _team_name(current_team)
	SelectionLabel.text = _selection_text()
	APLabel.text = "Team AP: %d" % _get_team_action_points(current_team)
	ModeLabel.text = _mode_text()
	StatusLabel.text = status_message
	PauseButton.visible = not get_tree().paused and not game_over
	PauseOverlay.visible = get_tree().paused
	if VictoryOverlay != null:
		VictoryOverlay.visible = game_over
		if game_over and VictoryLabel != null:
			VictoryLabel.text = _victory_message(team_won)
			VictoryLabel.add_theme_color_override("font_color", _victory_color(team_won))
		if game_over and VictorySubtitle != null:
			VictorySubtitle.text = "Game over"
		if PlayAgainButton != null:
			PlayAgainButton.visible = game_over
	EndTurnButton.disabled = multiplayer_pending or get_tree().paused or game_over or _get_team_action_points(current_team) <= 0
	if _is_online_mode():
		var can_end := (current_team == local_team) or (current_team == 0 and local_team == 2) or (current_team == 2 and local_team == 0)
		EndTurnButton.disabled = EndTurnButton.disabled or not can_end
	HostButton.disabled = multiplayer_pending or multiplayer_enabled
	JoinButton.disabled = multiplayer_pending or multiplayer_enabled
	DisconnectButton.disabled = not _is_online_mode()

func _selection_text() -> String:
	if selected_unit == null:
		return "Unit: none"
	return "Unit: %s | HP: %d | AP: %d" % [selected_unit.display_name, selected_unit.health, selected_unit.action_points]

func _mode_text() -> String:
	if get_tree().paused:
		return "Mode: paused"
	if multiplayer_pending:
		return "Mode: waiting for online opponent"
	if _is_online_mode() and current_team != local_team:
		return "Mode: waiting for opponent"
	if _get_team_action_points(current_team) <= 0:
		return "Mode: AP exhausted, ending turn"
	if current_team == AI_TEAM and not _is_online_mode():
		return "Mode: AI is thinking... (%s)" % AiController.get_mode_name()
	if selected_unit == null:
		return "Mode: select a unit"
	if selected_ability == null:
		return "Mode: choose an ability"
	match selected_ability.get_target_mode():
		Ability.TARGET_TILE:
			return "Mode: click a reachable tile"
		Ability.TARGET_UNIT:
			return "Mode: click an enemy unit"
	return "Mode: ready"

func _team_name(team: int) -> String:
	if _is_online_mode():
		match team:
			HUMAN_TEAM:
				return "Blue"
			2:
				return "Red"
			_:
				return "Team %d" % team
	match team:
		HUMAN_TEAM:
			return "Player"
		AI_TEAM:
			return "AI"
		_:
			return "Team %d" % team

func _victory_message(team: int) -> String:
	if _is_online_mode():
		if team == local_team:
			return "YOU WIN!"
		return "YOU LOSE!"
	match team:
		HUMAN_TEAM:
			return "Player Wins!"
		AI_TEAM:
			return "AI Wins!"
		_:
			return "Team %d Wins!" % team

func _victory_color(team: int) -> Color:
	if _is_online_mode():
		if team == local_team:
			return Color(1.0, 0.85, 0.2)
		return Color(1.0, 0.25, 0.25)
	if team == HUMAN_TEAM:
		return Color(1.0, 0.85, 0.2)
	if team == AI_TEAM:
		return Color(1.0, 0.25, 0.25)
	return Color.WHITE

func _get_team_action_points(team: int) -> int:
	if team == 2:
		team = 2
	if team < 0 or team >= team_ap.size():
		return 0
	return int(team_ap[team])

func get_team_action_points(team: int) -> int:
	return _get_team_action_points(team)

func spend_team_action_points(team: int, amount: int) -> void:
	if team == 2:
		team = 2
	if team < 0 or team >= team_ap.size():
		return
	team_ap[team] = maxi(int(team_ap[team]) - maxi(amount, 0), 0)
	if team_ap[team] <= 0:
		for unit in UnitManager.get_units_for_team(team):
			unit.action_points = 0
	_sync_to_match_state()

func _on_end_turn_button_pressed() -> void:
	if current_team == local_team and not get_tree().paused and not game_over and not multiplayer_pending:
		status_message = "Ending turn..."
		_sync_to_match_state()
		_submit_player_action(MatchRules.make_end_turn_action())

func _on_pause_button_pressed() -> void:
	if game_over:
		return
	get_tree().paused = not get_tree().paused
	status_message = "Paused. Press Continue to resume." if get_tree().paused else "Resumed."
	_update_ui()
	if not get_tree().paused and current_team == AI_TEAM and not _is_online_mode():
		AiController.call_deferred("take_turn")

func _on_play_again_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_host_button_pressed() -> void:
	host_online_match(_read_port_input())

func _on_join_button_pressed() -> void:
	join_online_match(HostInput.text.strip_edges(), _read_port_input())

func _on_disconnect_button_pressed() -> void:
	stop_online_match()
	status_message = "Disconnected from match."
	_update_ui()

func _on_hosting_started(port: int) -> void:
	status_message = "Hosting match on port %d." % port
	_update_multiplayer_panel()
	_update_ui()

func _on_hosting_failed(error_code: int) -> void:
	status_message = "Failed to host match. Error %d." % error_code
	multiplayer_pending = false
	multiplayer_enabled = false
	_update_multiplayer_panel()
	_update_ui()

func _on_connected_to_server() -> void:
	status_message = "Connected to host."
	_update_multiplayer_panel()
	NetworkManager.send_message_to_server({
		"type": "join_request",
	})
	_update_ui()

func _on_connection_failed() -> void:
	status_message = "Connection failed."
	multiplayer_pending = false
	multiplayer_enabled = false
	local_team = HUMAN_TEAM
	_update_multiplayer_panel()
	_update_ui()

func _on_disconnected_from_server() -> void:
	status_message = "Disconnected from match."
	multiplayer_pending = false
	multiplayer_enabled = false
	remote_peer_id = -1
	local_team = HUMAN_TEAM
	_update_multiplayer_panel()
	_update_ui()

func _on_peer_connected_to_match(peer_id: int) -> void:
	if NetworkManager.is_hosting():
		remote_peer_id = peer_id
		status_message = "Peer %d joined the match." % peer_id
		_update_multiplayer_panel()
		_update_ui()

func _on_peer_disconnected_from_match(peer_id: int) -> void:
	status_message = "Peer %d left the match." % peer_id
	if remote_peer_id == peer_id:
		remote_peer_id = -1
		multiplayer_pending = true
		multiplayer_enabled = false
	_update_multiplayer_panel()
	_update_ui()

func _on_network_message_received(message: Dictionary, from_peer: int) -> void:
	var message_type := String(message.get("type", ""))
	match message_type:
		"join_request":
			if NetworkManager.is_hosting():
				_handle_join_request(from_peer)
		"match_start":
			_handle_match_start(message)
		"submit_action":
			if NetworkManager.is_hosting():
				_handle_remote_submit_action(message, from_peer)
		"state_sync":
			_handle_state_sync(message)

func _handle_join_request(from_peer: int) -> void:
	remote_peer_id = from_peer
	multiplayer_pending = false
	multiplayer_enabled = true
	local_team = HUMAN_TEAM
	team_no = 3
	team_ap.resize(3)
	team_ap[0] = UnitManager.get_units_for_team(0).size()
	team_ap[1] = 0
	for unit in UnitManager.units:
		if unit.team == 1:
			unit.team = 2
	team_ap[2] = UnitManager.get_units_for_team(2).size()
	_sync_to_match_state()
	NetworkManager.send_message_to_peer(from_peer, {
		"type": "match_start",
		"team": 2,
		"state": to_dict(),
	})
	status_message = "Online match started. You are Team 0."
	_update_multiplayer_panel()
	_update_ui()
	status_message = "Online match started. You are Team 0."
	_update_multiplayer_panel()
	_update_ui()

func _handle_match_start(message: Dictionary) -> void:
	multiplayer_pending = false
	multiplayer_enabled = true
	local_team = int(message.get("team", AI_TEAM))
	if message.has("state") and message["state"] is Dictionary:
		from_dict(message["state"])
	status_message = "Online match started. You are Team %d." % local_team
	_update_multiplayer_panel()
	_update_ui()

func _handle_remote_submit_action(message: Dictionary, from_peer: int) -> void:
	if from_peer != remote_peer_id:
		return
	if current_team != 2:
		return
	var action = message.get("action", {})
	if not (action is Dictionary):
		return
	var result = apply_match_action(action)
	if bool(result.get("ok", false)):
		_broadcast_state_sync()

func _handle_state_sync(message: Dictionary) -> void:
	if not message.has("state") or not message["state"] is Dictionary:
		return
	print("=== JOINER RECEIVED STATE SYNC ===")
	print("current_team in received data: ", message["state"].get("current_team"))
	print("team_ap in received data: ", message["state"].get("team_ap"))
	from_dict(message["state"])
	_update_multiplayer_panel()
	_update_ui()

func _broadcast_state_sync() -> void:
	if not NetworkManager.is_hosting():
		return
	_sync_to_match_state()
	NetworkManager.broadcast_message({
		"type": "state_sync",
		"state": to_dict(),
	})

func _read_port_input() -> int:
	var parsed := int(PortInput.text.strip_edges())
	if parsed <= 0:
		return NetworkManager.DEFAULT_PORT
	return parsed

func _is_online_mode() -> bool:
	return multiplayer_enabled or multiplayer_pending

func is_online_mode_ex() -> bool:
	return multiplayer_enabled

func _update_multiplayer_panel() -> void:
	if MultiplayerInfoLabel == null:
		return
	if multiplayer_pending and NetworkManager.is_hosting():
		MultiplayerInfoLabel.text = "Hosting on port %d. Waiting for opponent..." % _read_port_input()
	elif multiplayer_pending:
		MultiplayerInfoLabel.text = "Connecting to %s:%d..." % [HostInput.text.strip_edges(), _read_port_input()]
	elif multiplayer_enabled:
		MultiplayerInfoLabel.text = "Connected. You are Team %d." % local_team
	else:
		MultiplayerInfoLabel.text = "Offline"
	_update_ui()

func to_dict() -> Dictionary:
	_sync_to_match_state()
	return match_state.to_dict(MapManager.to_dict(), UnitManager.to_dict())

func from_dict(data: Dictionary) -> void:
	var previous_team = current_team
	match_state.load_dict(data)
	_sync_from_match_state()
	if data.has("board") and data["board"] is Dictionary:
		MapManager.from_dict(data["board"])
	vt = MapManager.get_all_victory_tiles()
	if data.has("units") and data["units"] is Dictionary:
		UnitManager.from_dict(data["units"])
	if _is_online_mode():
		while team_ap.size() < 3:
			team_ap.append(0)
	selected_unit = null
	selected_ability = null
	game_over = match_state.team_won != -2
	if game_over:
		status_message = _victory_message(match_state.team_won)
	if _is_online_mode() and not game_over and current_team != previous_team:
		start_turn()
		return
	_sync_to_match_state()
	_sync_victory_overlay()
	_refresh_ability_panel()
	_refresh_highlights()
	_update_ui()

func _sync_victory_overlay() -> void:
	if VictoryOverlay == null:
		return
	VictoryOverlay.visible = game_over
	if not game_over:
		return
	if VictoryLabel != null:
		VictoryLabel.text = _victory_message(team_won)
	if VictorySubtitle != null:
		VictorySubtitle.text = "Game over"

func save_board_state(path: String = "user://board_save.tres") -> void:
	var state = BoardState.new()
	var data = to_dict()
	state.board = data["board"]
	state.current_team = data["current_team"]
	state.team_no = data["team_no"]
	state.team_vp = data["team_vp"]
	state.team_ap = data["team_ap"]
	state.defeated_teams = data["defeated_teams"]
	state.team_won = data["team_won"]
	state.status_message = data["status_message"]
	state.units = data["units"]
	ResourceSaver.save(state, path)

func load_board_state(path: String = "user://board_save.tres") -> bool:
	var resource = ResourceLoader.load(path)
	if resource == null or not resource is BoardState:
		return false
	var data := {
		"board": resource.board,
		"current_team": resource.current_team,
		"team_no": resource.team_no,
		"team_vp": resource.team_vp,
		"team_ap": resource.team_ap,
		"defeated_teams": resource.defeated_teams,
		"team_won": resource.team_won,
		"status_message": resource.status_message,
		"units": resource.units,
	}
	from_dict(data)
	return true

func _sync_to_match_state() -> void:
	match_state.current_team = current_team
	match_state.team_no = team_no
	match_state.team_vp = team_vp.duplicate(true)
	match_state.team_ap = team_ap.duplicate(true)
	match_state.defeated_teams = defeated_teams.duplicate(true)
	match_state.team_won = team_won
	match_state.status_message = status_message
	match_state.game_over = game_over
	match_state.units = UnitManager.units

func _sync_from_match_state() -> void:
	current_team = match_state.current_team
	team_no = match_state.team_no
	team_vp = match_state.team_vp.duplicate(true)
	team_ap = match_state.team_ap.duplicate(true)
	defeated_teams = match_state.defeated_teams.duplicate(true)
	team_won = match_state.team_won
	status_message = match_state.status_message
	game_over = match_state.game_over
	UnitManager.units = match_state.units
	if _is_online_mode():
		while team_ap.size() < 3:
			team_ap.append(0)
