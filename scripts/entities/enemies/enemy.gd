extends CharacterBody2D

# Настройки
@export var patrol_points: Node
@export var speed: int = 100
@export var chase_speed: int = 200
@export var wait_time: float = 0.3
@export var health_amount: int = 3
@export var damage_amount: int = 1
@export var attack_range: float = 36.0

# Ноды
@onready var animated_sprite = $AS_Enemy
@onready var timer = $WaitTimer
@onready var damage_timer = $DamageTimer
@onready var detection_area = $Area_Detection
@onready var attack_area = $Area_Attack

# Состояния
enum State { Idle, Walk, Chase, Attack, Return, Death }

# Переменные 
var current_state: State = State.Idle
var direction: Vector2 = Vector2.LEFT

var point_positions: Array[Vector2] = []
var current_point_position: int = 0
var chase_time: float = 0.0

var can_walk: bool = true
var is_dead: bool = false

var player: Node = null
var player_in_range = null


func _ready():

	attack_area.get_child(0).shape.radius = attack_range
	if patrol_points and patrol_points.get_child_count() >= 2: # Проверка точек для патрулирования
		for point in patrol_points.get_children():
			if point.has_method("get_global_position"):
				point_positions.append(point.global_position)
			else:
				print("Точка:", point.name)
		current_point_position = 0
		current_state = State.Walk
		update_current_point()
	else:
		push_error("Нужно 2 точки")

	timer.wait_time = wait_time


func _physics_process(delta: float) -> void:

	# FSM
	match current_state:
		State.Idle: 
			enemy_idle()
		State.Walk: 
			enemy_walk()
		State.Chase: 
			enemy_chase()
		State.Attack: 
			enemy_attack()
		State.Return: 
			enemy_return()
		State.Death: 
			enemy_death()

	move_and_slide()
	enemy_animations()

	# Возвращается к патрулированию, если погоня идёт слишком долго
	if current_state != State.Chase:
		chase_time = 0.0
	else:
		chase_time += delta
		if chase_time > 3.0:
			player = null
			current_point_position = find_nearest_patrol_point()
			update_current_point()
			current_state = State.Return
			


# Поведение

# Бездействие
func enemy_idle() -> void:
	velocity.x = move_toward(velocity.x, 0, speed)
	if can_walk:
		current_state = State.Walk
	elif timer.is_stopped():
		timer.start()

# Движение в спокойном состоянии
func enemy_walk() -> void:
	if !can_walk:
		return
	# Поиск ближайшей точки патрулирования
	var target = point_positions[current_point_position] 
	if abs(position.x - target.x) > 1.0:
		direction.x = sign(target.x - position.x)
		velocity.x = direction.x * speed
	else:
		current_point_position = (current_point_position + 1) % point_positions.size()
		update_current_point()
		can_walk = false
		timer.start()

	animated_sprite.flip_h = direction.x > 0


# Погоня, атака, выход из боя, смерть

# Погоня
func enemy_chase() -> void:
	if is_dead:
		return
	if player and is_instance_valid(player):
		var to_player = player.global_position - global_position
		if to_player.length() <= attack_range:
			current_state = State.Attack
			return

		direction.x = sign(to_player.x)
		velocity.x = direction.x * chase_speed
		animated_sprite.flip_h = direction.x > 0
	else: # Возвращение в патруль
		player = null
		current_point_position = find_nearest_patrol_point()
		update_current_point()
		current_state = State.Return

# Отображение атаки
func enemy_attack() -> void:
	velocity.x = 0
	animated_sprite.play("attack")

	if player and is_instance_valid(player):
		if global_position.distance_to(player.global_position) > attack_range:
			current_state = State.Chase

# Выход из боя - возврат к патрулированию
func enemy_return() -> void:
	var target = point_positions[current_point_position]
	if abs(position.x - target.x) > 1.0:
		direction.x = sign(target.x - position.x)
		velocity.x = direction.x * speed
		animated_sprite.flip_h = direction.x > 0
	else:
		current_state = State.Idle
		can_walk = false
		timer.start()

# Смерть
func enemy_death() -> void:
	if is_dead:
		return
	
	is_dead = true
	velocity = Vector2.ZERO
	can_walk = false
	animated_sprite.play("dying")

	Global.enemies_killed += 1
	
	await animated_sprite.animation_finished
	queue_free()


# Анимации

func enemy_animations() -> void:
	if is_dead:
		return
	match current_state:
		State.Idle:
			if !can_walk:
				animated_sprite.play("idle")
		State.Walk:
			if can_walk:
				animated_sprite.play("walk")
		State.Chase:
			if !animated_sprite.is_playing() or animated_sprite.animation != "run":
				animated_sprite.play("run")
		State.Attack:
			if !animated_sprite.is_playing() or animated_sprite.animation != "attack":
				animated_sprite.play("attack")


# Поиск маршрута

func update_current_point():
	if point_positions.size() > 0:
		current_point_position = clamp(current_point_position, 0, point_positions.size() - 1)
		var target = point_positions[current_point_position]
		direction = (target - position).normalized()
	else:
		print("Нет точек патруля.")


func find_nearest_patrol_point() -> int:
	var nearest_index = 0
	var min_distance = INF

	for pt in point_positions.size():
		var dist = global_position.distance_to(point_positions[pt])
		if dist < min_distance:
			min_distance = dist
			nearest_index = pt

	return nearest_index


# Сигналы

# Пауза перед сменой направления движения
func _on_timer_timeout() -> void:
	can_walk = true
	if current_state == State.Idle:
		current_state = State.Walk

# Получение урона
func _on_area_hitbox_area_entered(area: Area2D) -> void:
	
	if area.has_method("get_damage_amount"):
		health_amount -= area.damage_amount
		if current_state != State.Chase and current_state != State.Attack:
			player = get_node("/root/Main/Player")
			if player and is_instance_valid(player):
				current_state = State.Chase
		blink_effect()
		if health_amount <= 0:
			current_state = State.Death

# Зона обнаружения игрока
func _on_area_detection_body_entered(body: Node) -> void:
	if body.name == "Player":
		player = body
		current_state = State.Chase


func _on_area_detection_body_exited(body: Node) -> void:
	if body == player:
		player = null
		current_point_position = find_nearest_patrol_point()
		update_current_point()
		current_state = State.Return

# Мерцание противника при получении урона
func blink_effect() -> void:
	var tween = get_tree().create_tween()
	animated_sprite.modulate = Color.RED
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)
	

# Игрок в зоне поражения
func _on_area_attack_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = body
		$DamageTimer.start()

# Игрок вне зоны поражения
func _on_area_attack_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null
		$DamageTimer.stop()

# Таймер паузы между атаками
func _on_damage_timer_timeout() -> void:
	if player_in_range and is_instance_valid(player_in_range):
		if player_in_range.has_method("take_damage"):
			player_in_range.take_damage(damage_amount)
