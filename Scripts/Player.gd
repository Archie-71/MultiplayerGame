extends KinematicBody2D

const SPEED = 500

var hp = 100 setget set_hp
var velocity = Vector2(0, 0)
var shoot_mode = Global.WEAPONS.UNARMED
var is_reloading = false
var lr_flag = false

var player_bullet = load("res://Scenes/Player_bullet.tscn")
var player_hp = load("res://Scenes/Player_HP.tscn")
var username_text = load("res://Scenes/Username_text.tscn")

var username setget username_set
var username_text_instance = null
var player_hp_instance = null

puppet var puppet_hp = 100 setget puppet_hp_set
puppet var puppet_position = Vector2(0, 0) setget puppet_position_set
puppet var puppet_velocity = Vector2()
puppet var puppet_rotation = 0
puppet var puppet_username = "" setget puppet_username_set
puppet var puppet_body_anim = "unarmed" setget puppet_body_anim_set
puppet var puppet_body_frame = 0 setget puppet_body_frame_set
puppet var puppet_feet_frame = 0 setget puppet_feet_frame_set


onready var tween = $Tween
onready var feet = $Feet
onready var body = $Body
onready var reload_timer = $Reload_timer
onready var shoot_point = $Shoot_point
onready var shoot_point2 = $Shoot_point2
onready var hit_timer = $Hit_timer

func _ready():
	get_tree().connect("network_peer_connected", self, "_network_peer_connected")
	
	username_text_instance = Global.instance_node_at_location(username_text, Persistent_nodes, global_position)
	username_text_instance.player_following = self
	
	player_hp_instance = Global.instance_node_at_location(player_hp, Persistent_nodes, global_position)
	player_hp_instance.player_following = self
	
	update_shoot_mode(Global.WEAPONS.UNARMED)
	Global.alive_players.append(self)
	
	yield(get_tree(), "idle_frame")
	if get_tree().has_network_peer():
		if is_network_master():
			Global.player_master = self

func _process(delta: float) -> void:
	if username_text_instance != null:
		username_text_instance.name = "username" + name
		
	if player_hp_instance != null:
		player_hp_instance.health = hp
	
	if get_tree().has_network_peer():
		if is_network_master() and hp > 0:
			var x_input = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
			var y_input = int(Input.is_action_pressed("down")) - int(Input.is_action_pressed("up"))
			
			velocity = Vector2(x_input, y_input).normalized()
			
			if velocity.length() > 0:
				feet.play()
			else:
				feet.stop()
				feet.frame = 0
			
			move_and_slide(velocity * SPEED)
			
			look_at(get_global_mouse_position())
			
			if Input.is_action_pressed("click") and shoot_mode != Global.WEAPONS.UNARMED and not is_reloading:
				if shoot_mode == Global.WEAPONS.PISTOL:
					if lr_flag:
						rpc("instance_bullet", get_tree().get_network_unique_id(), shoot_point.global_position, shoot_point.global_position.angle_to_point(get_global_mouse_position()) + PI)
					else:
						rpc("instance_bullet", get_tree().get_network_unique_id(), shoot_point2.global_position, shoot_point2.global_position.angle_to_point(get_global_mouse_position()) + PI)
					lr_flag = !lr_flag
				elif shoot_mode == Global.WEAPONS.UZI:
					rpc("instance_bullet", get_tree().get_network_unique_id(), shoot_point.global_position, rotation + rand_range(-0.2, 0.2))
					rpc("instance_bullet", get_tree().get_network_unique_id(), shoot_point2.global_position, rotation + rand_range(-0.2, 0.2))
				is_reloading = true
				reload_timer.start()
			
			if Input.is_action_just_pressed("click"):
				body.play()
			
			if Input.is_action_just_released("click"):
				body.stop()
				body.frame = 0
				
			if Input.is_action_just_pressed("switch"):
				if shoot_mode == Global.WEAPONS.PISTOL:
					update_shoot_mode(Global.WEAPONS.UZI)
				elif shoot_mode == Global.WEAPONS.UZI:
					update_shoot_mode(Global.WEAPONS.PISTOL)
				is_reloading = false
			
		else:
			rotation = lerp_angle(rotation, puppet_rotation, delta * 8)
			
			if not tween.is_active():
				move_and_slide(puppet_velocity * SPEED)
	
	if hp <= 0:
		if username_text_instance != null:
			username_text_instance.visible = false
		
		if get_tree().has_network_peer():
			if get_tree().is_network_server():
				rpc("destroy")

func lerp_angle(from, to, weight):
	return from + short_angle_dist(from, to) * weight

func short_angle_dist(from, to):
	var max_angle = PI * 2
	var difference = fmod(to - from, max_angle)
	return fmod(2 * difference, max_angle) - difference

func puppet_position_set(new_value) -> void:
	puppet_position = new_value
	
	tween.interpolate_property(self, "global_position", global_position, puppet_position, 0.1)
	tween.start()

func set_hp(new_value):
	hp = new_value
	player_hp_instance.set_health(new_value)
	
	if get_tree().has_network_peer():
		if is_network_master():
			rset("puppet_hp", hp)

func puppet_hp_set(new_value):
	puppet_hp = new_value
	
	if get_tree().has_network_peer():
		if not is_network_master():
			hp = puppet_hp

func username_set(new_value) -> void:
	username = new_value
	
	if get_tree().has_network_peer():
		if is_network_master() and username_text_instance != null:
			username_text_instance.text = username
			rset("puppet_username", username)

func puppet_username_set(new_value) -> void:
	puppet_username = new_value
	
	if get_tree().has_network_peer():
		if not is_network_master() and username_text_instance != null:
			username_text_instance.text = puppet_username
			
func puppet_body_anim_set(new_anim) -> void:
	puppet_body_anim = new_anim
	
	if get_tree().has_network_peer():
		if not is_network_master():
			body.animation = puppet_body_anim
	
func puppet_body_frame_set(new_value) -> void:
	puppet_body_frame = new_value
	
	if get_tree().has_network_peer():
		if not is_network_master():
			body.frame = puppet_body_frame
	
func puppet_feet_frame_set(new_value) -> void:
	puppet_feet_frame = new_value
	
	if get_tree().has_network_peer():
		if not is_network_master():
			feet.frame = puppet_feet_frame

func _network_peer_connected(id) -> void:
	rset_id(id, "puppet_username", username)

sync func instance_bullet(id, pos, rot):
	var player_bullet_instance = Global.instance_node_at_location(player_bullet, Persistent_nodes, pos)
	player_bullet_instance.name = "Bullet" + name + str(Network.networked_object_name_index)
	player_bullet_instance.set_network_master(id)
	player_bullet_instance.player_rotation = rot
	player_bullet_instance.player_owner = id
	Network.networked_object_name_index += 1

sync func update_position(pos):
	global_position = pos
	puppet_position = pos
	
sync func update_animation(body_anim, feet_anim):
	body.animation = body_anim
	feet.animation = feet_anim

func update_shoot_mode(weapon):
	if weapon == Global.WEAPONS.UNARMED:
		body.animation = "unarmed"
	elif weapon == Global.WEAPONS.PISTOL:
		body.animation = "shoot_pistol"
		reload_timer.set("wait_time", 0.2)
	elif weapon == Global.WEAPONS.UZI:
		body.animation = "shoot_uzi"
		reload_timer.set("wait_time", 0.1)
	
	shoot_mode = weapon

func _on_Reload_timer_timeout():
	is_reloading = false

func _on_Hit_timer_timeout():
	modulate = Color(1, 1, 1, 1)

func _on_Hitbox_area_entered(area):
	if get_tree().is_network_server():
		if area.is_in_group("Player_damager") and area.get_parent().player_owner != int(name):
			rpc("hit_by_damager", area.get_parent().damage)
			
			area.get_parent().rpc("destroy")

sync func hit_by_damager(damage):
	hp -= damage
	modulate = Color(5, 5, 5, 1)
	hit_timer.start()

sync func enable() -> void:
	hp = 100
	shoot_mode = Global.WEAPONS.UNARMED
	update_shoot_mode(Global.WEAPONS.UNARMED)
	username_text_instance.visible = true
	player_hp_instance.visible = true
	visible = true
	$CollisionShape2D2.disabled = false
	$Hitbox/CollisionShape2D.disabled = false
	
	if get_tree().has_network_peer():
		if is_network_master():
			Global.player_master = self
	
	if not Global.alive_players.has(self):
		Global.alive_players.append(self)

sync func destroy() -> void:
	$CollisionShape2D2.disabled = true
	$Hitbox/CollisionShape2D.disabled = true
	
	feet.visible = false
	body.animation = "death"
	body.play()
	
	username_text_instance.visible = true
	player_hp_instance.visible = false
	Global.alive_players.erase(self)
	
	if get_tree().has_network_peer():
		if is_network_master():
			Global.player_master = null

func _exit_tree() -> void:
	Global.alive_players.erase(self)
	if get_tree().has_network_peer():
		if is_network_master():
			Global.player_master = null

func _on_Network_tick_timeout():
	if get_tree().has_network_peer():
		if is_network_master():
			rset_unreliable("puppet_position", global_position)
			rset_unreliable("puppet_velocity", velocity)
			rset_unreliable("puppet_rotation", rotation)
			rset_unreliable("puppet_body_anim", body.animation)
			rset_unreliable("puppet_body_frame", body.frame)
			rset_unreliable("puppet_feet_frame", feet.frame)
