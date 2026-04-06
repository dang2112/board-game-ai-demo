extends Unit
#platonic sniper

const HUMAN_TEXTURE := preload("res://assets/sniper1.png")
const AI_TEXTURE := preload("res://assets/sniper2.png")

func _ready():
	display_name = "Sniper"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health = 3
	team_textures = {
		0: HUMAN_TEXTURE,
		1: AI_TEXTURE,
	}
	
	var shoot = preload("res://abilities/ability_shoot.gd").new()
	shoot.attack_range = 8
	shoot.damage = 5
	
	var move = preload("res://abilities/ability_move.gd").new()
	move.move_range = 1
	
	abilities = [
		shoot,
		move
	]

	super._ready()
	if sprite != null:
		sprite.scale = Vector2(0.25, 0.25)
