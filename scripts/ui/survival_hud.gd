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
## Jogador usado pelo minimapa. Se não for atribuído, usa o jogador do respawn.
@export var player: Node3D
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
@onready var _prompt_panel: PanelContainer = %PromptLabel.get_parent()
@onready var _capacity_label: Label = %CapacityLabel
@onready var _minimap: WildboundMinimap = %Minimap
@onready var _hotbar: HotbarUI = %Hotbar
@onready var _inventory_summary: InventorySummary = %InventorySummary
@onready var _toast_feed: HudToastFeed = %ToastFeed
@onready var _damage_vignette: ColorRect = %DamageVignette
var _last_enemy_name := "Uma criatura"
@onready var _bag_label: Label = %BagLabel
@onready var _player_node: Node3D = respawn.player if respawn != null else null

var _message_left := 0.0
var _bag_refresh_left := 0.0
var _damage_tween: Tween
var _prompt_tween: Tween


func _ready() -> void:
	if player == null:
		player = _player_node
	if _minimap != null:
		_minimap.player = player
	if _inventory_summary != null:
		_inventory_summary.bind_inventory(inventory)
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
		respawn.bag_changed.connect(func(_bag): _update_bag_label.call_deferred())
	_refresh_inventory()
	_prompt_label.text = ""
	_prompt_panel.visible = false
	_message_label.text = ""


func _process(delta: float) -> void:
	_bag_refresh_left -= delta
	if _bag_refresh_left <= 0.0:
		_bag_refresh_left = 0.2
		_update_bag_label()
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message_label.text = ""


func show_message(text: String, duration: float = -1.0, kind: int = -1) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	_message_label.text = text
	_message_left = message_duration if duration < 0.0 else duration
	var toast_kind := _classify_message(text) if kind < 0 else kind
	_toast_feed.push_message(text, _message_left, toast_kind)


func get_message() -> String:
	return _message_label.text


func get_prompt() -> String:
	return _prompt_label.text


func get_inventory_text() -> String:
	return _inventory_label.text


const ACTION_INVENTORY := &"inventory"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_INVENTORY):
		toggle_inventory()
		get_viewport().set_input_as_handled()


## [I] mostra/esconde o inventário completo.
func toggle_inventory() -> void:
	set_inventory_open(not is_inventory_open())


func set_inventory_open(open: bool) -> void:
	if _inventory_summary == null or _inventory_summary.visible == open:
		return
	_inventory_summary.visible = open
	if open:
		_inventory_summary.modulate.a = 0.0
		_inventory_summary.scale = Vector2(0.92, 0.92)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_inventory_summary, "modulate:a", 1.0, 0.14)
		tween.tween_property(_inventory_summary, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_inventory_open() -> bool:
	return _inventory_summary != null and _inventory_summary.visible


## Liga a hotbar ao equipamento do jogador (chamado pelo PlayerEquipment).
func bind_equipment(equipment: PlayerEquipment) -> void:
	if _hotbar != null:
		_hotbar.bind_equipment(equipment)


func get_hotbar() -> HotbarUI:
	return _hotbar


func get_inventory_card_count() -> int:
	return _inventory_summary.get_item_card_count() if _inventory_summary != null else 0


func get_toast_count() -> int:
	return _toast_feed.get_visible_count() if _toast_feed != null else 0


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "VIDA  %d/%d" % [ceili(current), int(maximum)]


func _on_hunger_changed(current: float, maximum: float) -> void:
	_hunger_bar.max_value = maximum
	_hunger_bar.value = current
	var warning := current <= maximum * hunger_warning_ratio
	_hunger_label.text = ("! FOME  %d/%d" if warning else "FOME  %d/%d") % [int(current), int(maximum)]
	_hunger_bar.modulate = Color(1.0, 0.45, 0.35) if warning else Color.WHITE


func _refresh_inventory() -> void:
	if inventory == null:
		_inventory_label.text = ""
		_capacity_label.text = ""
		return
	_capacity_label.text = "MOCHILA %d/%d" % [inventory.used_slots(), inventory.capacity]
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
	_animate_prompt(target != null)


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
	var distance := roundi(_player_node.global_position.distance_to(bag.global_position))
	_bag_label.text = "MOCHILA %s  %d itens · %d m" % [_bag_arrow(bag), bag.total_items(), distance]


func _on_player_damaged(info: DamageInfo) -> void:
	if String(info.cause).begins_with("enemy:") and not health.is_dead():
		show_message("%s te atingiu! (-%d)" % [_source_name(info), roundi(info.amount)],
			1.5, HudToastFeed.Kind.DANGER)
		_last_enemy_name = _source_name(info)
		_flash_damage()


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
	_toast_feed.clear_all()
	show_message(text, 999.0, HudToastFeed.Kind.CRITICAL)
	_prompt_label.text = ""
	_prompt_panel.visible = false


func _on_player_respawned() -> void:
	_toast_feed.clear_all()
	show_message("Você reapareceu no ponto inicial", 2.5, HudToastFeed.Kind.INFO)


func _classify_message(text: String) -> int:
	var lower := text.to_lower()
	if "morreu" in lower or "derrubou" in lower:
		return HudToastFeed.Kind.CRITICAL
	if "atingiu" in lower or "noite" in lower or "uivo" in lower or "perigo" in lower:
		return HudToastFeed.Kind.DANGER
	if "sem " in lower or "não " in lower or "cheio" in lower or "falt" in lower or "calma" in lower:
		return HudToastFeed.Kind.WARNING
	if "comeu" in lower or "recuperada" in lower or "atadura" in lower or "fabric" in lower or "construí" in lower:
		return HudToastFeed.Kind.SUCCESS
	return HudToastFeed.Kind.INFO


func _animate_prompt(show: bool) -> void:
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if show:
		_prompt_panel.visible = true
		_prompt_panel.modulate.a = 0.0
		_prompt_tween = create_tween()
		_prompt_tween.tween_property(_prompt_panel, "modulate:a", 1.0, 0.12)
	elif _prompt_panel.visible:
		_prompt_tween = create_tween()
		_prompt_tween.tween_property(_prompt_panel, "modulate:a", 0.0, 0.1)
		_prompt_tween.tween_callback(func(): _prompt_panel.visible = false)


func _flash_damage() -> void:
	if _damage_tween != null and _damage_tween.is_valid():
		_damage_tween.kill()
	_damage_vignette.modulate.a = 1.0
	_health_bar.modulate = Color(1.35, 0.65, 0.6, 1.0)
	_damage_tween = create_tween().set_parallel(true)
	_damage_tween.tween_property(_damage_vignette, "modulate:a", 0.0, 0.38)
	_damage_tween.tween_property(_health_bar, "modulate", Color.WHITE, 0.3)


func _bag_arrow(bag: RecoveryBag) -> String:
	var offset := bag.global_position - _player_node.global_position
	var direction := Vector2(offset.x, offset.z).normalized()
	var pivot := _player_node.get_node_or_null("CameraPivot") as Node3D
	var yaw := pivot.global_rotation.y if pivot != null else _player_node.global_rotation.y
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(-forward.y, forward.x)
	var forward_amount := direction.dot(forward)
	var right_amount := direction.dot(right)
	if absf(forward_amount) >= absf(right_amount):
		return "↑" if forward_amount >= 0.0 else "↓"
	return "→" if right_amount >= 0.0 else "←"
