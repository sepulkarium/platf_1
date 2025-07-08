extends CharacterBody2D

# Значения
@export var speed = 250
const JUMP_FORCE = -400
var gravity = 1000
var direction := 0
var health := 5
var can_shoot := true
var is_hurt := false
var facing_left := false

# FSM
enum State { Idle, Run, Jump, Shoot, Hurt }
var state: State = State.Idle

# Ноды
@onready var sprite = $AS_Player
@onready var bullet_spawn = $Mark_BulletSpawn

# Пуля
@onready var bullet_scene = preload("res://scenes/entities/player/bullet.tscn")

# Сигналы
signal died
signal hp_changed(new_hp)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	match state:
		State.Idle:
			handle_idle()
		State.Run:
			handle_run()
		State.Jump:
			handle_jump()
		State.Shoot:
			handle_shoot()
		State.Hurt:
			handle_hurt()

	move_and_slide()

# Принимает вввод
func get_input():
	direction = Input.get_axis("ui_left", "ui_right")

# Состояния

func handle_idle():
	sprite.play("idle")
	get_input()
	velocity.x = 0

	sprite.flip_h = facing_left  # <- Maintain flip when idle

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_FORCE
		state = State.Jump
	elif Input.is_action_just_pressed("attack") and can_shoot:
		state = State.Shoot
	elif direction != 0:
		state = State.Run

# Бег
func handle_run():
	sprite.play("run")
	get_input()
	velocity.x = direction * speed

	if direction != 0:
		facing_left = direction < 0
	sprite.flip_h = facing_left

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_FORCE
		state = State.Jump
	elif Input.is_action_just_pressed("attack") and can_shoot:
		state = State.Shoot
	elif direction == 0:
		state = State.Idle

# Прыжок
func handle_jump():
	sprite.play("jump")
	get_input()
	velocity.x = direction * speed

	if direction != 0:
		facing_left = direction < 0
	sprite.flip_h = facing_left

	if is_on_floor():
		state = State.Run if direction != 0 else State.Idle
	elif Input.is_action_just_pressed("attack") and can_shoot:
		state = State.Shoot

# Выстрел
func handle_shoot():
	if sprite.animation != "shoot" and is_on_floor():
		fire_bullet()
		sprite.play("shoot")
		can_shoot = false
		velocity.x = 0

	sprite.flip_h = facing_left # Поддерживает праивльное положение спрайта

	if not sprite.is_playing():
		can_shoot = true
		state = State.Jump if not is_on_floor() else (State.Run if direction != 0 else State.Idle)

# Получение урона
func handle_hurt():
	if not is_hurt:
		sprite.play("hurt")
		is_hurt = true
		velocity.x = 0

	if not sprite.is_playing():
		is_hurt = false
		state = State.Idle

func take_damage(amount: int = 1):
	if state == State.Hurt:
		return

	health -= amount
	hp_changed.emit(health)

	if health <= 0:
		health = 0
		died.emit()
		hide()
	else:
		state = State.Hurt

# Выстрел
func fire_bullet():
	var bullet = bullet_scene.instantiate()
	bullet.position = bullet_spawn.global_position
	bullet.direction = Vector2.LEFT if facing_left else Vector2.RIGHT

	get_tree().current_scene.add_child(bullet)
