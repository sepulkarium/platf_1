extends Area2D

@export var speed := 400
var direction := Vector2.RIGHT
var damage_amount = 1

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func get_damage_amount():
		return damage_amount

# Уничтожение при столкновении
func _on_area_entered(area: Area2D) -> void:
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	queue_free()
