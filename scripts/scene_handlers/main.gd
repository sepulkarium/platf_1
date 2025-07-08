extends Node2D

@onready var enemies: Node = $Enemies
@onready var player: CharacterBody2D = $Player
@onready var hud: Control = $UI/HUD
@onready var game_over_screen: Control = $UI/GameOver


func _ready() -> void:
	player.died.connect(game_over)
	player.hp_changed.connect(change_hp)
	Global.win_condition = true

func game_over():
	for enemy in enemies.get_children():
		if enemy.current_state != enemy.State.Walk or enemy.current_state != enemy.State.Idle:
			enemy._on_area_detection_body_exited(player)
	game_over_screen.lb_kill_score.text = "Kill Score: " + str(Global.enemies_killed)
	game_over_screen.lb_game_over.text = "Победа" if Global.win_condition == true else "Поражение" # Проверка победы
	game_over_screen.show()

func _on_killzone_body_entered(body: Node2D) -> void:
	Global.win_condition = false
	game_over()

func change_hp(new_hp):
	hud.update_hearts(new_hp)
	Global.win_condition = true if new_hp > 0 else false # Проверка выживания игрока

func _on_area_finish_body_entered(body: Node2D) -> void:
	if body == player:
		body.state = body.State.Idle
		body.sprite.stop()
		body.set_physics_process(false)
		game_over()
