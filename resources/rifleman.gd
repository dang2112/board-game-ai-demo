extends Unit
#platonic rifleman

const HUMAN_TEXTURE := preload("res://assets/rifle1.png")
const AI_TEXTURE := preload("res://assets/rifle2.png")

func _ready():
	display_name = "Rifleman"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health = 10
	team_textures = {
		0: HUMAN_TEXTURE,
		1: AI_TEXTURE,
	}
	
	abilities = [
		preload("res://abilities/ability_shoot.gd").new(),
		preload("res://abilities/ability_move.gd").new()
	]

	super._ready()
	if sprite != null:
		sprite.scale = Vector2(0.25, 0.25)
