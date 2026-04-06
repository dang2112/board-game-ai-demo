extends Unit
#platonic sniper

func _ready():
	display_name = "Sniper"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health = 3
	
	var shoot = preload("res://abilities/ability_shoot.gd").new()
	shoot.attack_range = 7
	shoot.damage = 3
	
	var move = preload("res://abilities/ability_move.gd").new()
	move.move_range = 1
	
	abilities = [
		shoot,
		move
	]
