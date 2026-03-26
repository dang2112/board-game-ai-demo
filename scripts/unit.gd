class_name Unit
extends Node2D

var team: int #player is team 0
var health: int = 10
var active: int = 1 #0 means normally inactive; other integers can mean inactive due to other things

var position_on_grid: Vector2i

var abilities = [] #for now each unit has only 1 ability

func can_act():
	return active == 1

func perform_ability(ability, target):
	if not can_act():
		return false
	
	if ability.execute(self, target):
		return true
	
	return false
