class_name MatchState
extends RefCounted
#holds serialized data for current match

var current_team: int = 0
var team_no: int = 2
var team_vp: Array = []
var team_ap: Array = []
var defeated_teams: Array = []
var team_won: int = -2
var status_message: String = ""
var game_over: bool = false
var units: Array = []

func reset(team_count: int, starting_team: int, starting_status: String) -> void:
	current_team = starting_team
	team_no = team_count
	team_vp.clear()
	team_ap.clear()
	for _i in range(team_count):
		team_vp.append(0)
		team_ap.append(0)
	defeated_teams.clear()
	team_won = -2
	status_message = starting_status
	game_over = false

func to_dict(board: Dictionary, units: Dictionary) -> Dictionary:
	return {
		"board": board,
		"current_team": current_team,
		"team_no": team_no,
		"team_vp": team_vp.duplicate(true),
		"team_ap": team_ap.duplicate(true),
		"defeated_teams": defeated_teams.duplicate(true),
		"team_won": team_won,
		"status_message": status_message,
		"units": units,
	}

func load_dict(data: Dictionary) -> void:
	current_team = int(data.get("current_team", current_team))
	team_no = int(data.get("team_no", team_no))
	team_vp = data.get("team_vp", []).duplicate(true) if data.has("team_vp") else []
	team_ap = data.get("team_ap", []).duplicate(true) if data.has("team_ap") else []
	defeated_teams = data.get("defeated_teams", []).duplicate(true) if data.has("defeated_teams") else []
	team_won = int(data.get("team_won", team_won))
	status_message = String(data.get("status_message", status_message))
	game_over = team_won != -2
