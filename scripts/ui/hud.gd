extends Control

@onready var hearts_container = $HBC_HealthBar

@export var max_hp: int = 5
var current_hp: int = 5

@export var heart_texture: Texture2D

func _ready() -> void:
	update_hearts(max_hp)

# Индикация количества здоровья
func update_hearts(hp: int):
	current_hp = hp
	for item in hearts_container.get_children():
		item.queue_free()

	for icon in max_hp:
		var heart = TextureRect.new()
		heart.texture = heart_texture
		heart.custom_minimum_size = Vector2(32, 16)
		heart.modulate = Color(1, 1, 1, 1) if icon < current_hp else Color(1, 1, 1, 0.2)
		hearts_container.add_child(heart)
