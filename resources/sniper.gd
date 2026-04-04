extends Unit
#platonic sniper

func _ready():
	health = 6
	
	var shoot = preload("res://abilities/ability_shoot.gd").new()
	shoot.range = 8
	shoot.damage = 5
	
	var move = preload("res://abilities/ability_move.gd").new()
	move.range = 1
	
	abilities = [
		shoot,
		move
	]
