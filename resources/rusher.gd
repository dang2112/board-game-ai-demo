extends Unit
#platonic rusher

func _ready():
	display_name = "Rusher"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	health = 5
	
	var move = preload("res://abilities/ability_move.gd").new()
	move.move_range = 7
	
	var shoot = preload("res://abilities/ability_shoot.gd").new()
	shoot.attack_range = 1
	shoot.damage = 10
	
	abilities = [
		move,
		shoot
	]
