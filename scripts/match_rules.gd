class_name MatchRules
extends RefCounted
#owns turn flow, action validation, action application, and legal-action generation

static func make_action(actor_pos: Vector2i, ability_index: int, target_pos: Vector2i) -> Dictionary:
	return {
		"type": "use_ability",
		"actor_pos": actor_pos,
		"ability_index": ability_index,
		"target_pos": target_pos,
	}

static func make_end_turn_action() -> Dictionary:
	return {"type": "end_turn"}

static func start_turn(game, state: MatchState) -> void:
	if state.team_won != -1:
		state.game_over = true
		state.status_message = game._victory_message(state.team_won)
		return

	game.selected_unit = null
	game.selected_ability = null
	state.status_message = "AI is thinking..." if state.current_team == game.AI_TEAM else "Blue units are yours. Click a blue unit, then choose an ability."
	_ensure_team_arrays(state)
	state.team_ap[state.current_team] = game.UnitManager.get_units_for_team(state.current_team).size()
	for unit in game.UnitManager.get_units_for_team(state.current_team):
		unit.action_points = 1

	_sync_defeated_teams(game, state)
	if _check_elimination_victory(game, state):
		return

	if state.team_won == state.current_team:
		state.game_over = true
		state.status_message = game._victory_message(state.current_team)
		return

	if state.defeated_teams.find(state.current_team) != -1:
		state.status_message = "You have lost!"

static func end_turn(game, state: MatchState, victory_tiles: Array) -> void:
	if state.game_over:
		return

	game.selected_unit = null
	game.selected_ability = null
	_ensure_team_arrays(state)
	for pos in victory_tiles:
		var capturing_unit = game.UnitManager.get_unit_at(pos)
		if capturing_unit != null and capturing_unit.team == state.current_team:
			state.team_vp[state.current_team] = int(state.team_vp[state.current_team]) + 1

	if int(state.team_vp[state.current_team]) >= int(game.VP_COND):
		state.team_won = state.current_team
		state.game_over = true
		state.status_message = game._victory_message(state.team_won)
		return

	_sync_defeated_teams(game, state)
	if _check_elimination_victory(game, state):
		return

	state.current_team = (state.current_team + 1) % state.team_no

static func validate_action(game, state: MatchState, action: Dictionary) -> Dictionary:
	if action.is_empty():
		return {"ok": false, "reason": "Missing action."}

	if state.game_over or state.team_won != -1:
		return {"ok": false, "reason": "The match is over."}

	if String(action.get("type", "")) == "end_turn":
		return {"ok": true}

	var actor_pos: Vector2i = action.get("actor_pos", Vector2i.ZERO)
	var actor: Unit = game.UnitManager.get_unit_at(actor_pos)
	if actor == null:
		return {"ok": false, "reason": "No acting unit at that position."}

	if actor.team != state.current_team:
		return {"ok": false, "reason": "It is not that unit's turn."}

	if not actor.can_act():
		return {"ok": false, "reason": "That unit cannot act."}

	var ability_index := int(action.get("ability_index", -1))
	if ability_index < 0 or ability_index >= actor.abilities.size():
		return {"ok": false, "reason": "Invalid ability."}

	var ability: Ability = actor.abilities[ability_index]
	var target_pos: Vector2i = action.get("target_pos", Vector2i.ZERO)
	var valid_targets = ability.get_valid_targets(actor, game.MapManager, game.UnitManager, _team_ap_for(state, state.current_team))
	if not valid_targets.has(target_pos):
		return {"ok": false, "reason": "Invalid target."}

	var clicked_unit = game.UnitManager.get_unit_at(target_pos)
	var action_cost = _get_action_cost(game, actor, ability, target_pos, clicked_unit)
	if action_cost > _team_ap_for(state, state.current_team):
		return {"ok": false, "reason": "Not enough Team AP."}

	return {
		"ok": true,
		"actor": actor,
		"ability": ability,
		"target_unit": clicked_unit,
		"target_pos": target_pos,
		"action_cost": action_cost,
	}

static func apply_action(game, state: MatchState, action: Dictionary) -> Dictionary:
	var validation = validate_action(game, state, action)
	if not bool(validation.get("ok", false)):
		return validation

	if String(action.get("type", "")) == "end_turn":
		end_turn(game, state, game.vt)
		return {"ok": true, "end_turn": true}

	var actor: Unit = validation["actor"]
	var ability: Ability = validation["ability"]
	var target_unit: Unit = validation["target_unit"]
	var target_pos: Vector2i = validation["target_pos"]
	var action_cost: int = int(validation["action_cost"])
	var success := false

	match ability.get_target_mode():
		Ability.TARGET_TILE:
			success = actor.perform_ability(ability, target_pos)
		Ability.TARGET_UNIT:
			if target_unit != null:
				success = actor.perform_ability(ability, target_unit)

	if not success:
		return {"ok": false, "reason": "Ability failed."}

	actor.action_points = 0
	_spend_team_ap(state, state.current_team, action_cost)
	state.status_message = _build_action_message(actor, ability, target_pos, target_unit, action_cost)

	return {
		"ok": true,
		"message": state.status_message,
		"board_pos": target_pos if target_unit == null else target_unit.position_on_grid,
		"cost": action_cost,
		"auto_end_turn": _team_ap_for(state, state.current_team) <= 0 and not state.game_over,
	}

static func get_legal_actions(game, state: MatchState, team: int) -> Array:
	var actions: Array = []
	if state.game_over or team != state.current_team or _team_ap_for(state, team) <= 0:
		return actions

	for unit in game.UnitManager.get_units_for_team(team):
		if not unit.can_act():
			continue
		for ability_index in range(unit.abilities.size()):
			var ability: Ability = unit.abilities[ability_index]
			for target_pos in ability.get_valid_targets(unit, game.MapManager, game.UnitManager, _team_ap_for(state, team)):
				actions.append(make_action(unit.position_on_grid, ability_index, target_pos))

	return actions

static func _sync_defeated_teams(game, state: MatchState) -> void:
	for team in range(state.team_no):
		if game.UnitManager.get_units_for_team(team).is_empty() and state.defeated_teams.find(team) == -1:
			state.defeated_teams.append(team)

static func _check_elimination_victory(game, state: MatchState) -> bool:
	if state.team_won != -1:
		state.game_over = true
		state.status_message = game._victory_message(state.team_won)
		return true

	if state.defeated_teams.size() < state.team_no - 1:
		return false

	var surviving_team := -1
	for team in range(state.team_no):
		if state.defeated_teams.find(team) == -1:
			if surviving_team != -1:
				return false
			surviving_team = team

	if surviving_team == -1 or state.defeated_teams.size() != state.team_no - 1:
		return false

	state.team_won = surviving_team
	state.game_over = true
	state.status_message = game._victory_message(state.team_won)
	return true

static func _ensure_team_arrays(state: MatchState) -> void:
	while state.team_vp.size() < state.team_no:
		state.team_vp.append(0)
	while state.team_ap.size() < state.team_no:
		state.team_ap.append(0)

static func _team_ap_for(state: MatchState, team: int) -> int:
	if team < 0 or team >= state.team_ap.size():
		return 0
	return int(state.team_ap[team])

static func _spend_team_ap(state: MatchState, team: int, amount: int) -> void:
	if team < 0 or team >= state.team_ap.size():
		return
	state.team_ap[team] = maxi(int(state.team_ap[team]) - maxi(amount, 0), 0)

static func _get_action_cost(game, actor: Unit, ability: Ability, target_pos: Vector2i, target_unit: Unit) -> int:
	if ability.get_target_mode() == Ability.TARGET_TILE:
		return ability.get_action_cost(actor, target_pos, game.MapManager)
	if ability.get_target_mode() == Ability.TARGET_UNIT and target_unit != null:
		return ability.get_action_cost(actor, target_unit, game.MapManager)
	return ability.get_action_cost(actor, null, game.MapManager)

static func _build_action_message(actor: Unit, ability: Ability, target_pos: Vector2i, target_unit: Unit, cost: int) -> String:
	if actor == null or ability == null:
		return "Action complete."

	var actor_team := "Blue" if actor.team == 0 else "Red"
	var cost_text := "%d AP" % cost

	match ability.get_target_mode():
		Ability.TARGET_TILE:
			return "%s %s moved to (%d, %d) (-%s)" % [actor_team, actor.display_name, target_pos.x, target_pos.y, cost_text]
		Ability.TARGET_UNIT:
			if target_unit != null:
				var target_team := "Blue" if target_unit.team == 0 else "Red"
				return "%s %s shot %s %s (-%s)" % [actor_team, actor.display_name, target_team, target_unit.display_name, cost_text]

	return "%s %s acted (-%s)" % [actor_team, actor.display_name, cost_text]
