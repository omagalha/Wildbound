class_name PlayerEquipment
extends Node
## Equipamento derivado do inventário: arma ativa, tocha e ataduras.
##
## Nada aqui é salvo: a arma é escolhida pelo que está no inventário (a
## melhor disponível) e a tocha começa apagada ao carregar.
##   - Arma: lança de pedra se houver, senão a clava improvisada.
##   - [T] acende/apaga a tocha (precisa ter uma).
##   - [H] usa uma atadura (cura [member bandage_heal]; recusa com vida cheia).

signal message(text: String)
signal weapon_changed(definition: WeaponDefinition)
signal torch_toggled(lit: bool)

const ACTION_TORCH := &"toggle_torch"
const ACTION_BANDAGE := &"use_bandage"
const SPEAR := &"stone_spear"
const TORCH := &"torch"
const BANDAGE := &"bandage"

@export var inventory: Inventory
@export var health: HealthComponent
@export var weapon: WeaponController
## Onde a tocha fica presa (o visual do personagem).
@export var visual: Node3D
@export var club_definition: WeaponDefinition
@export var spear_definition: WeaponDefinition
@export var bandage_heal: float = 30.0
@export var bandage_cooldown: float = 2.0
## Opcional: avisos vão direto para o HUD.
@export var hud: SurvivalHUD

var torch_lit := false
var _bandage_left := 0.0
var _torch_node: Node3D
var _torch_light: OmniLight3D
var _spear_visual: Node3D
var _flicker := 0.0


func _ready() -> void:
	if inventory != null:
		inventory.changed.connect(refresh)
	if hud != null:
		message.connect(func(t): hud.show_message(t))
	_build_torch()
	refresh()


func _physics_process(delta: float) -> void:
	_bandage_left = maxf(_bandage_left - delta, 0.0)
	if torch_lit and _torch_light != null:
		_flicker += delta * 9.0
		_torch_light.light_energy = 1.6 + sin(_flicker) * 0.12 + sin(_flicker * 2.7) * 0.08


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION_TORCH):
		toggle_torch()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_BANDAGE):
		use_bandage()
		get_viewport().set_input_as_handled()


## Reavalia arma e tocha a partir do inventário.
func refresh() -> void:
	_update_weapon()
	if torch_lit and not has_torch():
		set_torch(false)


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


func _update_weapon() -> void:
	if weapon == null:
		return
	var wanted := club_definition
	if spear_definition != null and inventory != null and inventory.has_item(SPEAR):
		wanted = spear_definition
	if wanted == null or weapon.definition == wanted:
		_update_weapon_visual()
		return
	var had_weapon := weapon.definition != null
	weapon.definition = wanted
	_update_weapon_visual()
	weapon_changed.emit(wanted)
	if had_weapon and is_inside_tree():
		message.emit("Arma equipada: %s" % wanted.display_name)


func _update_weapon_visual() -> void:
	var club := weapon.get_node_or_null("Club") as Node3D
	if club == null:
		return
	var is_spear := weapon.definition == spear_definition and spear_definition != null
	for child in club.get_children():
		if child != _spear_visual:
			(child as Node3D).visible = not is_spear
	if is_spear and _spear_visual == null:
		_spear_visual = _build_spear()
		club.add_child(_spear_visual)
	if _spear_visual != null:
		_spear_visual.visible = is_spear


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
	_torch_node = Node3D.new()
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
