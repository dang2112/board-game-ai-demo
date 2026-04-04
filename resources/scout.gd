extends Unit
#platonic scout

func _ready():
	health = 7
	
	var move = preload("res://abilities/ability_move.gd").new()
	move.range = 5
	
	abilities = [
		move
	]
