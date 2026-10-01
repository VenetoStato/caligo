extends Node

const BOSS := preload("res://Levels/Scenes/Dogana/drowned_customs_warden.tscn")


func _ready() -> void:
	var boss := BOSS.instantiate() as CharacterBody2D
	add_child(boss)
	await get_tree().process_frame
	var body := boss.get_node("CollisionShape2D") as CollisionShape2D
	var hurt := boss.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D
	var attack_area := boss.get_node("AttackHitbox") as Area2D
	var attack := boss.get_node("AttackHitbox/CollisionShape2D") as CollisionShape2D
	var contact := boss.get_node("ContactDamage/CollisionShape2D") as CollisionShape2D
	if not _valid_rect(body) or not _valid_rect(hurt) or not _valid_rect(attack) or not _valid_rect(contact):
		return _fail("missing or non-rectangular boss collision")
	var body_size := _effective_size(body)
	var hurt_size := _effective_size(hurt)
	var attack_size := _effective_size(attack)
	var contact_size := _effective_size(contact)
	if hurt_size.x < body_size.x or hurt_size.y < body_size.y:
		return _fail("hurtbox is smaller than the physical body")
	if hurt_size.x > 86.0 or hurt_size.y > 98.0:
		return _fail("hurtbox extends too far outside the boss silhouette")
	if contact_size.x > hurt_size.x or contact_size.y > hurt_size.y:
		return _fail("contact damage is larger than the vulnerable silhouette")
	if attack_size.x < 86.0 or attack_size.x > 112.0 or attack_size.y > 76.0:
		return _fail("melee hitbox does not match the shown attack arc")
	if attack_area.monitoring or attack_area.monitorable:
		return _fail("boss attack hitbox starts active")
	boss.call("_enable_melee_hitbox", 1.0)
	await get_tree().physics_frame
	if absf(attack_area.position.x) < 45.0 or not attack_area.monitoring:
		return _fail("active melee hitbox is not placed in front of the boss")
	print("CALIGO_BOSS_HITBOX_COHERENCE_OK: body, hurt, contact and melee zones aligned")
	get_tree().quit(0)


func _valid_rect(collision: CollisionShape2D) -> bool:
	return collision != null and collision.shape is RectangleShape2D


func _effective_size(collision: CollisionShape2D) -> Vector2:
	return (collision.shape as RectangleShape2D).size * collision.scale.abs()


func _fail(message: String) -> void:
	push_error("BOSS_HITBOX_COHERENCE_FAIL: %s" % message)
	get_tree().quit(1)
