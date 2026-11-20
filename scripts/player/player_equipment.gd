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
## Itens (além das ferramentas) que ganham espaço na hotbar, na ordem de prioridade.
const USABLE_ITEMS := [TORCH, BANDAGE, &"cooked_meat", &"wild_berries"]
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
## Outras armas e ferramentas de segurar (machados e picaretas melhores...).
## O id da definição é o id do item no inventário.
@export var extra_definitions: Array[WeaponDefinition] = []
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
var _held_visuals := {}  # id -> Node3D montado na mão
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
	for id in hotbar_items():
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
	if is_holdable(id):
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
		if is_holdable(slots[i]):
			_hold(slots[i], true)
			return


## Armas e ferramentas de segurar: clava + todas as definições conhecidas.
func held_definitions() -> Array[WeaponDefinition]:
	var out: Array[WeaponDefinition] = []
	for def in [spear_definition, axe_definition, pickaxe_definition]:
		if def != null:
			out.append(def)
	for def in extra_definitions:
		if def != null and not out.has(def):
			out.append(def)
	return out


func is_holdable(id: StringName) -> bool:
	return id == CLUB or definition_for(id) != null


## Itens que ganham espaço na hotbar: ferramentas e armas, depois os de usar.
func hotbar_items() -> Array[StringName]:
	var out: Array[StringName] = []
	for def in held_definitions():
		out.append(def.id)
	for id in USABLE_ITEMS:
		out.append(id)
	return out


## Definição de segurar de um item (null se não for arma/ferramenta).
func definition_for(id: StringName) -> WeaponDefinition:
	for def in held_definitions():
		if def.id == id:
			return def
	return null


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
	if not is_holdable(id) or not _owns(id):
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
	var def := definition_for(id)
	return def if def != null else club_definition


func _apply_held() -> void:
	var wanted := _definition_for(held_item)
	if interaction != null:
		interaction.held_item = held_item
		interaction.held_tool = wanted
	if weapon == null:
		return
	if wanted != null and weapon.definition != wanted:
		weapon.definition = wanted
		weapon_changed.emit(wanted)
	_update_weapon_visual()


func _update_weapon_visual() -> void:
	var club := weapon.get_node_or_null("Club") as Node3D
	if club == null:
		return
	if held_item != CLUB and not _held_visuals.has(held_item):
		var def := definition_for(held_item)
		if def != null:
			var built := build_held_visual(def)
			club.add_child(built)
			_held_visuals[held_item] = built
	for child in club.get_children():
		var node := child as Node3D
		if node == null:
			continue
		if _held_visuals.values().has(node):
			node.visible = _held_visuals.get(held_item) == node
		else:
			node.visible = held_item == CLUB  # a clava são os filhos originais do Club


## Monta o visual de uma arma/ferramenta a partir dos dados, com a pegada na
## origem: o cabo sai do punho para +Y e a frente (lâmina, ponta) aponta para -X.
static func build_held_visual(def: WeaponDefinition) -> Node3D:
	var root := Node3D.new()
	root.name = String(def.id).to_pascal_case()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = def.handle_color
	wood.roughness = 0.9
	var stone := StandardMaterial3D.new()
	stone.albedo_color = def.head_color
	stone.roughness = 0.55
	var length := def.handle_length
	var grip := 0.12 if def.visual_kind != &"spear" else length * 0.38  # cabo abaixo do punho
	var top := length - grip
	if def.visual_kind == &"sword":
		# Empunhadura curta, guarda e lâmina longa saindo do punho.
		var metal := StandardMaterial3D.new()
		metal.albedo_color = def.head_color
		metal.metallic = 0.75
		metal.roughness = 0.3
		_add_mesh(root, _cylinder(0.024, 0.026, 0.2, wood), Vector3(0, 0.0, 0), Vector3.ZERO)
		_add_mesh(root, _box(Vector3(0.05, 0.05, 0.05), metal), Vector3(0, -0.11, 0), Vector3.ZERO)
		_add_mesh(root, _box(Vector3(0.22, 0.035, 0.05), metal), Vector3(0, 0.11, 0), Vector3.ZERO)
		var blade_len := length - 0.25
		_add_mesh(root, _box(Vector3(0.065, blade_len, 0.014), metal), Vector3(0, 0.13 + blade_len * 0.5, 0), Vector3.ZERO)
		var tip := PrismMesh.new()
		tip.size = Vector3(0.065, 0.1, 0.014)
		tip.material = metal
		_add_mesh(root, tip, Vector3(0, 0.13 + blade_len + 0.05, 0), Vector3.ZERO)
		return root
	_add_mesh(root, _cylinder(0.026, 0.032, length, wood), Vector3(0, top - length * 0.5, 0), Vector3.ZERO)
	match def.visual_kind:
		&"axe":
			# Lâmina em cunha para a frente (-X) e um contrapeso atrás.
			var blade := PrismMesh.new()
			blade.size = Vector3(0.2, 0.24, 0.045)
			blade.left_to_right = 0.5
			blade.material = stone
			_add_mesh(root, blade, Vector3(-0.1, top - 0.1, 0), Vector3(0, 0, PI * 0.5))
			_add_mesh(root, _box(Vector3(0.07, 0.09, 0.06), stone), Vector3(0.04, top - 0.1, 0), Vector3.ZERO)
			_add_mesh(root, _box(Vector3(0.05, 0.06, 0.07), wood.duplicate()), Vector3(0, top - 0.1, 0), Vector3.ZERO)
		&"pickaxe":
			# Cabeça curva com duas pontas, centrada no topo.
			for side in [-1.0, 1.0]:
				var spike := _cylinder(0.0, 0.035, 0.28, stone)
				spike.radial_segments = 4
				_add_mesh(root, spike, Vector3(0.14 * side, top - 0.04, 0), Vector3(0, 0, -side * (PI * 0.5 - 0.35)))
			_add_mesh(root, _box(Vector3(0.08, 0.07, 0.06), stone), Vector3(0, top - 0.03, 0), Vector3.ZERO)
		&"spear":
			var tip := _cylinder(0.0, 0.055, 0.26, stone)
			tip.radial_segments = 4
			_add_mesh(root, tip, Vector3(0, top + 0.13, 0), Vector3.ZERO)
			_add_mesh(root, _cylinder(0.04, 0.04, 0.06, wood.duplicate()), Vector3(0, top - 0.02, 0), Vector3.ZERO)
		_:
			var head := SphereMesh.new()
			head.radius = 0.12
			head.height = 0.26
			head.radial_segments = 7
			head.rings = 4
			head.material = wood
			_add_mesh(root, head, Vector3(0, top - 0.04, 0), Vector3.ZERO)
	return root


static func _cylinder(top_r: float, bottom_r: float, height: float, mat: Material) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bottom_r
	m.height = height
	m.radial_segments = 6
	m.rings = 0
	m.material = mat
	return m


static func _box(size: Vector3, mat: Material) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	return m


static func _add_mesh(root: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


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
