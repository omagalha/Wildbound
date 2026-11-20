class_name PlayerEquipment
extends Node
## Hotbar de 9 espaços e o item na mão do jogador.
##
## - Espaço 1 é sempre a clava improvisada. Ferramentas, armas, tocha,
##   ataduras e comida entram sozinhas no primeiro espaço livre quando chegam
##   ao inventário, e saem quando acabam.
## - [1]–[9] (ou a roda do mouse) escolhem o espaço:
##     clava, lança, machado, picareta -> vai para a mão (arma do golpe e
##       ferramenta da coleta: machado e picareta só ajudam se estiverem na mão);
##     tocha -> acende/apaga na outra mão;  atadura -> cura;  comida -> come.
## - [T] tocha e [H] atadura continuam funcionando direto.
## A hotbar e o item na mão são salvos pelo SaveManager.

signal message(text: String)
signal weapon_changed(definition: WeaponDefinition)
signal torch_toggled(lit: bool)
signal held_changed(item_id: StringName)
signal hotbar_changed

const ACTION_TORCH := &"toggle_torch"
const ACTION_BANDAGE := &"use_bandage"
const CLUB := &"improvised_club"
const SPEAR := &"stone_spear"
const AXE := &"stone_axe"
const PICKAXE := &"stone_pickaxe"
const TORCH := &"torch"
const BANDAGE := &"bandage"
const SLOT_COUNT := 9
## Itens que vão para a mão.
const HOLDABLE := [CLUB, SPEAR, AXE, PICKAXE]
## Itens que ganham espaço na hotbar, na ordem de prioridade.
const HOTBAR_ITEMS := [SPEAR, AXE, PICKAXE, TORCH, BANDAGE, &"cooked_meat", &"wild_berries"]
const NAMES := {CLUB: "Clava improvisada"}

@export var inventory: Inventory
@export var health: HealthComponent
@export var weapon: WeaponController
## Onde a tocha fica presa (o visual do personagem).
@export var visual: Node3D
@export var club_definition: WeaponDefinition
@export var spear_definition: WeaponDefinition
@export var axe_definition: WeaponDefinition
@export var pickaxe_definition: WeaponDefinition
@export var food: FoodConsumer
## Recebe o item na mão (as fontes de recurso consultam).
@export var interaction: InteractionDetector
## Números não trocam de espaço no modo de construção (lá escolhem a peça).
@export var placement: PlacementController
@export var crafting_menu: CraftingMenu
@export var bandage_heal: float = 30.0
@export var bandage_cooldown: float = 2.0
## Raio em que a tocha acesa espanta criaturas que temem o fogo.
@export var torch_fear_radius: float = 7.0
## Opcional: avisos vão direto para o HUD.
@export var hud: SurvivalHUD

var torch_lit := false
var slots: Array[StringName] = []
var selected := 0
var held_item: StringName = CLUB
var _bandage_left := 0.0
var _torch_node: Node3D
var _torch_light: OmniLight3D
var _spear_visual: Node3D
var _tool_visuals := {}
var _flicker := 0.0


func _ready() -> void:
	slots.resize(SLOT_COUNT)
	slots.fill(&"")
	slots[0] = CLUB
	if inventory != null:
		inventory.changed.connect(refresh)
	if hud != null:
		message.connect(func(t): hud.show_message(t))
	_build_torch()
	refresh()
	if hud != null:
		hud.bind_equipment.call_deferred(self)


func _physics_process(delta: float) -> void:
	_bandage_left = maxf(_bandage_left - delta, 0.0)
	if torch_lit and _torch_light != null:
		_flicker += delta * 9.0
		_torch_light.light_energy = 1.6 + sin(_flicker) * 0.12 + sin(_flicker * 2.7) * 0.08


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_TORCH):
		toggle_torch()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION_BANDAGE):
		use_bandage()
		get_viewport().set_input_as_handled()
		return
	if not _hotbar_input_allowed():
		return
	for i in SLOT_COUNT:
		if event.is_action_pressed(StringName("hotbar_%d" % (i + 1))):
			select_slot(i)
			get_viewport().set_input_as_handled()
			return
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_held(-1)
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_held(1)


## Sincroniza a hotbar com o inventário e reaplica o item na mão.
func refresh() -> void:
	var changed := false
	for i in range(1, SLOT_COUNT):
		if slots[i] != &"" and not _owns(slots[i]):
			slots[i] = &""
			changed = true
	for id in HOTBAR_ITEMS:
		if _owns(id) and not slots.has(id):
			var free := slots.find(&"")
			if free >= 0:
				slots[free] = id
				changed = true
	if not _owns(held_item):
		_hold(CLUB, false)
	if torch_lit and not has_torch():
		set_torch(false)
	_apply_held()
	if changed:
		hotbar_changed.emit()


## Escolhe um espaço (0–8). Devolve true se algo aconteceu.
func select_slot(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT:
		return false
	var id := slots[index]
	if id == &"":
		return false
	if id in HOLDABLE:
		_hold(id, true)
		return true
	match id:
		TORCH:
			return toggle_torch()
		BANDAGE:
			return use_bandage()
	if food != null:
		return food.try_eat_item(id) == FoodConsumer.REASON_OK
	return false


## Passa para o próximo (ou anterior) item de segurar na hotbar.
func cycle_held(direction: int) -> void:
	for step in range(1, SLOT_COUNT + 1):
		var i := posmod(selected + step * direction, SLOT_COUNT)
		if slots[i] in HOLDABLE:
			_hold(slots[i], true)
			return


func slot_of(id: StringName) -> int:
	return slots.find(id)


func item_name(id: StringName) -> String:
	if NAMES.has(id):
		return NAMES[id]
	var item := inventory.catalog.get_item(id) if inventory != null and inventory.catalog != null else null
	return item.display_name if item != null else String(id)


func current_weapon() -> WeaponDefinition:
	return weapon.definition if weapon != null else null


func has_torch() -> bool:
	return inventory != null and inventory.has_item(TORCH)


func toggle_torch() -> bool:
	if not has_torch():
		message.emit("Você não tem uma tocha (fabrique com [C])")
		return false
	set_torch(not torch_lit)
	return true


func set_torch(lit: bool) -> void:
	if torch_lit == lit:
		return
	torch_lit = lit
	if _torch_node != null:
		_torch_node.visible = lit
	torch_toggled.emit(lit)
	hotbar_changed.emit()


## Usa uma atadura. Devolve true se curou.
func use_bandage() -> bool:
	if health == null or inventory == null or health.is_dead():
		return false
	if not inventory.has_item(BANDAGE):
		message.emit("Sem ataduras (fabrique com [C])")
		return false
	if _bandage_left > 0.0:
		return false
	if health.current_health >= health.max_health:
		message.emit("Vida cheia")
		return false
	inventory.remove_item(BANDAGE, 1)
	var healed := health.heal(bandage_heal)
	_bandage_left = bandage_cooldown
	message.emit("Atadura: +%d de vida" % roundi(healed))
	return true


func get_save_data() -> Dictionary:
	var out := []
	for id in slots:
		out.append(String(id))
	return {"slots": out, "held": String(held_item)}


func apply_save_data(data: Dictionary) -> void:
	var saved: Array = data.get("slots", [])
	for i in range(1, SLOT_COUNT):
		var id := StringName(String(saved[i])) if i < saved.size() else &""
		if id == CLUB or slots.slice(0, i).has(id):
			id = &""
		slots[i] = id
	_hold(StringName(String(data.get("held", CLUB))), false)
	refresh()
	hotbar_changed.emit()


# ---------- interno ----------

func _owns(id: StringName) -> bool:
	return id == CLUB or (inventory != null and inventory.has_item(id))


func _hotbar_input_allowed() -> bool:
	if placement != null and placement.active:
		return false
	if crafting_menu != null and crafting_menu.is_open:
		return false
	return health == null or not health.is_dead()


func _hold(id: StringName, announce: bool) -> void:
	if not (id in HOLDABLE) or not _owns(id):
		id = CLUB
	var index := slots.find(id)
	selected = index if index >= 0 else 0
	var changed := held_item != id
	held_item = id
	_apply_held()
	if changed:
		held_changed.emit(id)
		hotbar_changed.emit()
		if announce:
			message.emit("Na mão: %s" % item_name(id))


func _definition_for(id: StringName) -> WeaponDefinition:
	match id:
		SPEAR:
			return spear_definition if spear_definition != null else club_definition
		AXE:
			return axe_definition if axe_definition != null else club_definition
		PICKAXE:
			return pickaxe_definition if pickaxe_definition != null else club_definition
	return club_definition


func _apply_held() -> void:
	if interaction != null:
		interaction.held_item = held_item
	if weapon == null:
		return
	var wanted := _definition_for(held_item)
	if wanted != null and weapon.definition != wanted:
		weapon.definition = wanted
		weapon_changed.emit(wanted)
	_update_weapon_visual()


func _update_weapon_visual() -> void:
	var club := weapon.get_node_or_null("Club") as Node3D
	if club == null:
		return
	if held_item == SPEAR and _spear_visual == null:
		_spear_visual = _build_spear()
		club.add_child(_spear_visual)
	for id in [AXE, PICKAXE]:
		if held_item == id and not _tool_visuals.has(id):
			var tool := _build_tool(id)
			club.add_child(tool)
			_tool_visuals[id] = tool
	for child in club.get_children():
		var node := child as Node3D
		if node == _spear_visual:
			node.visible = held_item == SPEAR
		elif _tool_visuals.values().has(node):
			node.visible = _tool_visuals.get(held_item) == node
		else:
			node.visible = held_item == CLUB


func _build_tool(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "Axe" if id == AXE else "Pickaxe"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.5, 0.36, 0.22)
	var handle := CylinderMesh.new()
	handle.top_radius = 0.03
	handle.bottom_radius = 0.035
	handle.height = 0.7
	handle.radial_segments = 6
	handle.rings = 0
	handle.material = wood
	var handle_mi := MeshInstance3D.new()
	handle_mi.mesh = handle
	handle_mi.position = Vector3(0, 0.2, 0)
	handle_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(handle_mi)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.58, 0.6, 0.63)
	var head_mi := MeshInstance3D.new()
	head_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if id == AXE:
		var blade := PrismMesh.new()
		blade.size = Vector3(0.26, 0.2, 0.05)
		blade.material = stone
		head_mi.mesh = blade
		head_mi.rotation.z = -PI * 0.5
		head_mi.position = Vector3(0.1, 0.5, 0)
	else:
		var pick := CylinderMesh.new()
		pick.top_radius = 0.0
		pick.bottom_radius = 0.045
		pick.height = 0.5
		pick.radial_segments = 4
		pick.rings = 0
		pick.material = stone
		head_mi.mesh = pick
		head_mi.rotation.z = PI * 0.5
		head_mi.position = Vector3(0.0, 0.52, 0)
	root.add_child(head_mi)
	return root


func _build_spear() -> Node3D:
	var root := Node3D.new()
	root.name = "Spear"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.5, 0.36, 0.22)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.03
	shaft.bottom_radius = 0.035
	shaft.height = 1.7
	shaft.radial_segments = 6
	shaft.rings = 0
	shaft.material = wood
	var shaft_mi := MeshInstance3D.new()
	shaft_mi.mesh = shaft
	shaft_mi.rotation.x = -PI * 0.5 + 0.25
	shaft_mi.position = Vector3(0, 0.1, -0.45)
	shaft_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shaft_mi)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55, 0.57, 0.6)
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.07
	tip.height = 0.25
	tip.radial_segments = 4
	tip.rings = 0
	tip.material = stone
	var tip_mi := MeshInstance3D.new()
	tip_mi.mesh = tip
	tip_mi.rotation.x = -PI * 0.5 + 0.25
	tip_mi.position = Vector3(0, 0.33, -1.33)
	tip_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tip_mi)
	return root


func _build_torch() -> void:
	if visual == null:
		return
	var fear := FireLight.new()
	fear.radius = torch_fear_radius
	_torch_node = fear
	_torch_node.name = "Torch"
	_torch_node.position = Vector3(-0.45, 0.95, -0.25)
	_torch_node.visible = false
	visual.add_child(_torch_node)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.32, 0.2)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.04
	stick.bottom_radius = 0.03
	stick.height = 0.6
	stick.radial_segments = 5
	stick.rings = 0
	stick.material = wood
	var stick_mi := MeshInstance3D.new()
	stick_mi.mesh = stick
	stick_mi.position = Vector3(0, 0.2, 0)
	stick_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_torch_node.add_child(stick_mi)
	var fire := StandardMaterial3D.new()
	fire.albedo_color = Color(1.0, 0.6, 0.15)
	fire.emission_enabled = true
	fire.emission = Color(1.0, 0.5, 0.1)
	fire.emission_energy_multiplier = 3.0
	fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flame := CylinderMesh.new()
	flame.top_radius = 0.0
	flame.bottom_radius = 0.08
	flame.height = 0.22
	flame.radial_segments = 5
	flame.rings = 0
	flame.material = fire
	var flame_mi := MeshInstance3D.new()
	flame_mi.mesh = flame
	flame_mi.position = Vector3(0, 0.6, 0)
	flame_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_torch_node.add_child(flame_mi)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.68, 0.35)
	_torch_light.light_energy = 1.6
	_torch_light.omni_range = 11.0
	_torch_light.omni_attenuation = 1.2
	_torch_light.shadow_enabled = false
	_torch_light.position = Vector3(0, 0.75, 0)
	_torch_node.add_child(_torch_light)
