extends Unit
#platonic scout

const HUMAN_TEXTURE := preload("res://assets/scout1.png")
const AI_TEXTURE := preload("res://assets/scout2.png")

func _ready():
	display_name = "Scout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health = 7
	team_textures = {
		0: HUMAN_TEXTURE,
		1: AI_TEXTURE,
	}
	
	var move = preload("res://abilities/ability_move.gd").new()
	move.move_range = 5
	
	var shoot = preload("res://abilities/ability_shoot.gd").new()
	shoot.attack_range = 2
	shoot.damage = 7
	
	abilities = [
		shoot,
		move
	]

	super._ready()
	if sprite != null:
		sprite.scale = Vector2(0.18, 0.18)
