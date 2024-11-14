extends Area2D
class_name HookPoint

@onready var target_sprite = preload("res://Assets/target.png")
@onready var target_close_sprite = preload("res://Assets/target_close.png")


@onready var marker : Marker2D = $Marker2D
@onready var sprite : Sprite2D = $Sprite2D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func get_marker_pos() -> Vector2:
	return marker.global_position


func set_close_active(active : bool) -> void:
	if active:
		sprite.texture = target_close_sprite
	else:
		sprite.texture = target_sprite
		
