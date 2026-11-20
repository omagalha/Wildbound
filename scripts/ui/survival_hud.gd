class_name SurvivalHUD
extends CanvasLayer
## HUD de sobrevivência: vida, fome, inventário, aviso de interação e mensagens.
##
## Só escuta sinais; nunca altera o estado do jogo.

@export var health: HealthComponent
@export var hunger: HungerComponent
@export var inventory: Inventory
@export var interaction: InteractionDetector
@export var food_consumer: FoodConsumer
@export var respawn: SimpleRespawn
## Abaixo desta fração, a barra de fome fica em destaque.
@export_range(0.0, 1.0) var hunger_warning_ratio: float = 0.25
@export var message_duration: float = 2.5

const EAT_MESSAGES := {
	&"full": "Você não está com fome",
	&"no_item": "Sem comida no inventário",
	&"cooldown": "Calma, ainda comendo",
	&"dead": "",
}

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _hunger_bar: ProgressBar = %HungerBar
@onready var _hunger_label: Label = %HungerLabel
@onready var _inventory_label: Label = %InventoryLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _message_label: Label = %MessageLabel
var _last_enemy_name := "Uma criatura"
@onready var _bag_label: Label = %BagLabel
@onready var _player_node: Node3D = respawn.player if respawn != null else null

var _message_left := 0.0


func _ready() -> void:
	if health != null:
		health.health_changed.connect(_on_health_changed)
		_on_health_changed(health.current_health, health.max_health)
	if hunger != null:
		hunger.hunger_changed.connect(_on_hunger_changed)
		_on_hunger_changed(hunger.current_hunger, hunger.max_hunger)
	if inventory != null:
		inventory.changed.connect(_refresh_inventory)
	if interaction != null:
		interaction.focus_changed.connect(_on_focus_changed)
		interaction.interacted.connect(_on_interacted)
	if food_consumer != null:
		food_consumer.eat_result.connect(_on_eat_result)
	if health != null:
		health.damaged.connect(_on_player_damaged)
	if respawn != null:
		respawn.player_died.connect(_on_player_died)
		respawn.player_respawned.connect(_on_player_respawned)
	_refresh_inventory()
	_prompt_label.text = ""
	_message_label.text = ""


func _process(delta: float) -> void:
	_update_bag_label()
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message_label.text = ""


func show_message(text: String, duration: float = -1.0) -> void:
	_message_label.text = text
	_message_left = message_duration if duration < 0.0 else duration


func get_message() -> String:
	return _message_label.text


func get_prompt() -> String:
	return _prompt_label.text


func get_inventory_text() -> String:
	return _inventory_label.text


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "Vida %d/%d" % [ceili(current), int(maximum)]


func _on_hunger_changed(current: float, maximum: float) -> void:
	_hunger_bar.max_value = maximum
	_hunger_bar.value = current
	var warning := current <= maximum * hunger_warning_ratio
	_hunger_label.text = ("! Fome %d/%d" if warning else "Fome %d/%d") % [int(current), int(maximum)]
	_hunger_bar.modulate = Color(1.0, 0.45, 0.35) if warning else Color.WHITE


func _refresh_inventory() -> void:
	if inventory == null:
		_inventory_label.text = ""
		return
	var lines: PackedStringArray = ["Inventário %d/%d" % [inventory.used_slots(), inventory.capacity]]
	if inventory.catalog != null:
		for item in inventory.catalog.items:
			var amount := inventory.count(item.id)
			if amount > 0:
				lines.append("%s: %d" % [item.display_name, amount])
	if lines.size() == 1:
		lines.append("(vazio)")
	_inventory_label.text = "\n".join(lines)


func _on_focus_changed(target: Node, prompt: String) -> void:
	_prompt_label.text = "[E] %s" % prompt if target != null else ""


func _on_interacted(_target: Node, result: Dictionary) -> void:
	show_message(result.get("message", ""))


func _on_eat_result(ok: bool, reason: StringName, item: ItemDefinition) -> void:
	if ok and item != null:
		show_message("Comeu %s (+%d fome)" % [item.display_name, int(item.food_value)])
	else:
		show_message(EAT_MESSAGES.get(reason, ""))


func get_bag_text() -> String:
	return _bag_label.text


func _update_bag_label() -> void:
	var bag: RecoveryBag = respawn.active_bag if respawn != null else null
	if bag == null or not is_instance_valid(bag) or _player_node == null:
		_bag_label.text = ""
		return
	_bag_label.text = "Mochila: %d m" % roundi(_player_node.global_position.distance_to(bag.global_position))


func _on_player_damaged(info: DamageInfo) -> void:
	if String(info.cause).begins_with("enemy:") and not health.is_dead():
		show_message("%s te atingiu! (-%d)" % [_source_name(info), roundi(info.amount)], 1.5)
		_last_enemy_name = _source_name(info)


func _source_name(info: DamageInfo) -> String:
	if info.source != null and is_instance_valid(info.source) and info.source.get("definition") != null:
		return info.source.definition.display_name
	return "Uma criatura"


func _on_player_died(cause: StringName) -> void:
	var text := "Você morreu"
	if cause == DamageInfo.CAUSE_STARVATION:
		text = "Você morreu de fome"
	elif String(cause).begins_with("enemy:"):
		text = "%s te derrubou" % _last_enemy_name
	if respawn != null and respawn.active_bag != null and is_instance_valid(respawn.active_bag):
		text += " — seus itens ficaram na mochila"
	show_message(text, 999.0)
	_prompt_label.text = ""


func _on_player_respawned() -> void:
	show_message("Você reapareceu no ponto inicial")
