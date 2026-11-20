class_name SimpleRespawn
extends Node
## Morte e respawn dos modos normais (GDD 008), num único fluxo guiado por [DeathRules].
##
## Ao morrer: desativa o jogador; se as regras mandarem, move os itens do inventário
## para a Mochila de Recuperação numa única operação; depois de um instante leva o
## jogador ao leito ativo (ou ao ponto inicial) com os atributos do preset.
##
## Ainda não há: Exaustão (1.0), várias mochilas (1.0), mapa de mochilas, equipamento.
## Nome mantido por compatibilidade; corresponde ao DeathManager + RespawnManager da spec.

signal player_died(cause: StringName)
signal player_respawned
signal respawn_point_changed(bed: SurvivalBed)
signal bag_changed(bag: RecoveryBag)

const BAG_SCENE := preload("res://scenes/world/recovery_bag.tscn")

@export var player: CharacterBody3D
@export var health: HealthComponent
@export var hunger: HungerComponent
@export var inventory: Inventory
@export var interaction: InteractionDetector
@export var spawn_point: Node3D
@export var building_manager: BuildingManager
## Onde as mochilas são criadas.
@export var bag_root: Node3D
## Regras do preset atual (injetadas pelo DifficultyManager).
@export var death_rules: DeathRules
## Segundos entre a morte e o respawn.
@export var respawn_delay: float = 2.5
## Distância ao lado do leito onde o jogador reaparece.
@export var bed_side_offset: float = 1.2
## Intervalo de registro da última posição segura (jogador no chão).
@export var safe_position_interval: float = 2.0

var active_bed: SurvivalBed = null
var active_bag: RecoveryBag = null
var last_safe_position := Vector3.ZERO
var _waiting := false
var _safe_timer := 0.0
var _next_bag := 1


func _ready() -> void:
	if spawn_point != null:
		last_safe_position = spawn_point.global_position
	if health != null:
		health.died.connect(_on_died)
	if building_manager != null:
		building_manager.piece_built.connect(_on_piece_added)
		building_manager.piece_restored.connect(_on_piece_added)
		building_manager.piece_removed.connect(_on_piece_removed)


func _physics_process(delta: float) -> void:
	_safe_timer -= delta
	if _safe_timer <= 0.0:
		_safe_timer = safe_position_interval
		record_safe_position()


func is_waiting() -> bool:
	return _waiting


## Guarda a posição atual como segura se o jogador estiver vivo e no chão.
func record_safe_position() -> void:
	if player == null or _waiting or (health != null and health.is_dead()):
		return
	if player.is_on_floor():
		last_safe_position = player.global_position


## Torna este leito o ponto de retorno (só um ativo por vez).
func set_active_bed(bed: SurvivalBed) -> void:
	if active_bed != null and is_instance_valid(active_bed):
		active_bed.is_active_respawn = false
	active_bed = bed
	if bed != null:
		bed.is_active_respawn = true
	respawn_point_changed.emit(bed)


## Posição onde o jogador vai reaparecer agora.
func get_respawn_position() -> Vector3:
	if active_bed != null and is_instance_valid(active_bed):
		return active_bed.global_position + active_bed.global_transform.basis.x * bed_side_offset + Vector3.UP * 0.1
	return spawn_point.global_position if spawn_point != null else Vector3.ZERO


func _on_died(cause: StringName) -> void:
	if _waiting:
		return
	_waiting = true
	_set_player_enabled(false)
	if death_rules != null and death_rules.drop_carried_items:
		drop_inventory_into_bag(last_safe_position)
	player_died.emit(cause)
	get_tree().create_timer(respawn_delay, false, true).timeout.connect(respawn_now)


## Move todo o inventário para a mochila numa operação única. No MVP há uma mochila
## ativa: se já existir uma, os itens dela são unidos à nova (nada se perde — DR13).
func drop_inventory_into_bag(position: Vector3) -> RecoveryBag:
	if inventory == null or bag_root == null:
		return null
	var items := inventory.get_all()
	var previous := active_bag if active_bag != null and is_instance_valid(active_bag) else null
	if items.is_empty() and previous == null:
		return null
	var bag := _create_bag(StringName("bag_%d" % _next_bag), position)
	_next_bag += 1
	if previous != null:
		bag.add_contents(previous.contents)
		previous.contents.clear()
		previous.queue_free()
	bag.add_contents(items)
	inventory.load_counts({})
	return bag


## Executa o respawn imediatamente (também usado pelos testes).
func respawn_now() -> void:
	if not _waiting:
		return
	_waiting = false
	var rules := death_rules
	if player != null:
		player.global_position = get_respawn_position()
		player.velocity = Vector3.ZERO
	if health != null:
		health.revive(health.max_health * (rules.respawn_health_ratio if rules != null else 0.75))
	if hunger != null:
		hunger.set_hunger(hunger.max_hunger * (rules.respawn_hunger_ratio if rules != null else 0.5))
	_set_player_enabled(true)
	player_respawned.emit()


# ---------- save ----------

func get_bags_data() -> Array:
	var list := []
	if active_bag != null and is_instance_valid(active_bag) and active_bag.total_items() > 0:
		var items := {}
		for id in active_bag.contents:
			items[String(id)] = active_bag.contents[id]
		var p := active_bag.global_position
		list.append({"id": String(active_bag.bag_id), "position": [p.x, p.y, p.z], "items": items})
	return list


func restore_bags(data: Array) -> void:
	if active_bag != null and is_instance_valid(active_bag):
		active_bag.queue_free()
	active_bag = null
	for entry in data:
		var position := Vector3(float(entry["position"][0]), float(entry["position"][1]), float(entry["position"][2]))
		var bag := _create_bag(StringName(entry.get("id", "bag_restored")), position)
		bag.add_contents(entry.get("items", {}))
		var number := String(bag.bag_id).get_slice("_", 1).to_int()
		_next_bag = maxi(_next_bag, number + 1)


func _create_bag(id: StringName, position: Vector3) -> RecoveryBag:
	var bag := BAG_SCENE.instantiate() as RecoveryBag
	bag.bag_id = id
	bag.name = String(id)
	bag_root.add_child(bag)
	bag.global_position = position
	bag.emptied.connect(_on_bag_emptied)
	active_bag = bag
	bag_changed.emit(bag)
	return bag


func _on_bag_emptied(bag: RecoveryBag) -> void:
	if bag == active_bag:
		active_bag = null
		bag_changed.emit(null)


func _on_piece_added(piece: BuildingPiece) -> void:
	if piece is SurvivalBed:
		(piece as SurvivalBed).set_as_respawn_requested.connect(set_active_bed)


func _on_piece_removed(piece_id: StringName, _refund: Dictionary) -> void:
	if active_bed != null and (not is_instance_valid(active_bed) or active_bed.piece_id == piece_id):
		active_bed = null
		respawn_point_changed.emit(null)


func _set_player_enabled(enabled: bool) -> void:
	if player != null:
		player.set_physics_process(enabled)
		if not enabled:
			player.velocity = Vector3.ZERO
	if interaction != null:
		interaction.enabled = enabled
