extends Unit
#platonic rusher

const HUMAN_TEXTURE := preload("res://assets/rusher1.png")
const AI_TEXTURE := preload("res://assets/rusher2.png")

func _ready():
	display_name = "Rusher"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health = 5
	team_textures = {
		0: HUMAN_TEXTURE,
		1: AI_TEXTURE,
	}
	
	var move = preload("res://abilities/ability_move.gd").new()
	move.move_range = 7
	
	var shoot = preload("res://abilities/ability_shoot.gd").new()
	shoot.attack_range = 1
	shoot.damage = 10
	
	abilities = [
		move,
		shoot
	]

	super._ready()
	if sprite != null:
		sprite.scale = Vector2(0.16, 0.16)
