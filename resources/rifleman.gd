extends Unit
#platonic rifleman

func _ready():
	health = 10
	
	abilities = [
		preload("res://abilities/ability_shoot.gd").new(),
		preload("res://abilities/ability_move.gd").new()
	]
