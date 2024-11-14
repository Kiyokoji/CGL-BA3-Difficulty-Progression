extends Area2D

var has_been_triggered : bool = false
@onready var game : Game = $"../.."

@export var last_situation : bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_area_entered(area):
	#if area.is_in_group("HookArea"):
		#return
	#if !has_been_triggered:
		#has_been_triggered = true
		#game.next_level()
	pass


func _on_body_entered(body):
	if body is not Player:
		return
	if !has_been_triggered:
		has_been_triggered = true
		if last_situation:
			game.end_game()
		else:
			game.next_level()
