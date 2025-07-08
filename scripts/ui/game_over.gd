extends Control

@onready var lb_game_over: Label = $HBC_GameOver/VBC_GameOver/Lb_GameOver
@onready var lb_kill_score: Label = $HBC_GameOver/VBC_GameOver/Lb_KillScore


func _on_bt_restart_pressed() -> void: # Перезапуск уровня
	get_tree().reload_current_scene() 
