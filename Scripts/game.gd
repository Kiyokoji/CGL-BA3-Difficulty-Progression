extends Node2D
class_name Game

var current_level : int = 0

@onready var cam : Camera2D = $Camera2D
@onready var cam_points : Node2D = $CamPoints

@onready var spawn_points : Node2D = $SpawnPoints

@onready var player : CharacterBody2D = $Player

@onready var respawn_label : Label = $Camera2D/Label

var cam_list = []
var respawns_per_level : Array = [0, 0, 0, 0, 0]

# Called when the node enters the scene tree for the first time.
func _ready():
	var c = cam_points.get_child(0) as Marker2D
	cam.global_position = c.global_position
	spawn(current_level)


func next_level():
	current_level += 1
	var c = cam_points.get_child(current_level) as Marker2D
	cam.global_position = c.global_position


func spawn(current : int) -> void:
	var s = spawn_points.get_child(current_level) as Marker2D
	player.global_position = s.global_position
	pass


func respawn() -> void:
	respawns_per_level[current_level] += 1
	spawn(current_level)


func _on_bottom_area_entered(area):
	respawn()
	

func end_game() -> void:
	var label_text : String = "Respawns: %s, %s, %s, %s, %s" % [respawns_per_level[0], 
																respawns_per_level[1],
																respawns_per_level[2],
																respawns_per_level[3],
																respawns_per_level[4]]
	respawn_label.text = label_text
	respawn_label.show()
	pass
