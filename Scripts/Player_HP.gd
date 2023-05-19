extends Node2D

var player_following = null
var health = 100 setget set_health

onready var health_bar = $HealthFull

func _process(_delta):
	if player_following != null:
		global_position = player_following.global_position

func set_health(hp):
	health = hp
	health_bar.rect_size.x = 42 * health / 100
