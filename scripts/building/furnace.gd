class_name Furnace
extends BuildingPiece
## Fornalha: funde minério de ferro em lingotes, aos poucos.
##
## [E] com lingotes prontos: recolhe. [E] sem lingotes: coloca todo o minério
## de ferro e a lenha necessária (1 madeira para cada 2 minérios). Enquanto
## houver 2 minérios e 1 lenha, ela queima: fogo na boca, luz, fumaça, e
## espanta criaturas que temem o fogo. Cada lingote leva [member smelt_time] s.
## O conteúdo vai para o save, e a fornalha não pode ser removida com coisas dentro.

signal smelted(total_ingots: int)

const ORE := &"iron_ore"
const FUEL := &"wood"
const INGOT := &"iron_ingot"
const ORE_PER_INGOT := 2
const FUEL_PER_INGOT := 1

@export var smelt_time: float = 8.0
@export var max_ore: int = 20

var ore := 0
var fuel := 0
var ingots := 0
var progress := 0.0

@onready var _glow: MeshInstance3D = get_node_or_null("Mouth")
@onready var _light: OmniLight3D = get_node_or_null("FireGlow")
@onready var _fear: FireLight = get_node_or_null("FearLight")
@onready var _smoke: CPUParticles3D = get_node_or_null("Smoke")


func _ready() -> void:
	_update_fire()


func _physics_process(delta: float) -> void:
	tick(delta)


## Avança a fundição (separado para testes).
func tick(delta: float) -> void:
	if piece_id == &"" or not is_burning():
		return
	progress += delta
	if _light != null:
		_light.light_energy = 1.4 + sin(Time.get_ticks_msec() * 0.012) * 0.2
	if progress >= smelt_time:
		progress = 0.0
		ore -= ORE_PER_INGOT
		fuel -= FUEL_PER_INGOT
		ingots += 1
		smelted.emit(ingots)
		_update_fire()


func is_burning() -> bool:
	return ore >= ORE_PER_INGOT and fuel >= FUEL_PER_INGOT


func get_interaction_prompt() -> String:
	return _status_line()


func get_interaction_prompt_for(interactor: InteractionDetector) -> String:
	if ingots > 0:
		return "Pegar %d lingote%s de ferro" % [ingots, "s" if ingots > 1 else ""]
	var inventory: Inventory = interactor.inventory if interactor != null else null
	if inventory != null and inventory.count(ORE) >= ORE_PER_INGOT and ore < max_ore:
		return "Colocar minério na fornalha"
	return _status_line()


func can_interact(_interactor: InteractionDetector) -> bool:
	return piece_id != &""


func interact(interactor: InteractionDetector) -> Dictionary:
	var inventory: Inventory = interactor.inventory if interactor != null else null
	if inventory == null:
		return {"ok": false, "message": "Sem inventário"}
	if ingots > 0:
		var got := inventory.add_up_to(INGOT, ingots)
		if got <= 0:
			return {"ok": false, "message": "Inventário cheio"}
		ingots -= got
		_update_fire()
		return {"ok": true, "message": "+%d Lingote de ferro" % got}
	return load_from(inventory)


## Coloca minério (em pares) e a lenha que faltar. Devolve o resultado.
func load_from(inventory: Inventory) -> Dictionary:
	var room := max_ore - ore
	var ore_in := mini(inventory.count(ORE), room)
	ore_in -= ore_in % ORE_PER_INGOT
	if ore_in <= 0:
		if ore >= max_ore:
			return {"ok": false, "message": "A fornalha está cheia"}
		return {"ok": false, "message": "Precisa de 2 minérios de ferro e 1 madeira por lingote"}
	var fuel_needed := maxi((ore + ore_in) / ORE_PER_INGOT * FUEL_PER_INGOT - fuel, 0)
	var fuel_in := mini(inventory.count(FUEL), fuel_needed)
	if fuel + fuel_in < FUEL_PER_INGOT:
		return {"ok": false, "message": "Falta lenha: 1 madeira para cada 2 minérios"}
	inventory.remove_item(ORE, ore_in)
	if fuel_in > 0:
		inventory.remove_item(FUEL, fuel_in)
	ore += ore_in
	fuel += fuel_in
	_update_fire()
	return {"ok": true, "message": "Fornalha: +%d minério, +%d lenha. %s" % [ore_in, fuel_in, _status_line()]}


## Coisas dentro impedem a remoção (nada some em silêncio).
func blocks_removal() -> bool:
	return ore > 0 or fuel > 0 or ingots > 0


func get_piece_data() -> Dictionary:
	return {"ore": ore, "fuel": fuel, "ingots": ingots, "progress": progress}


func apply_piece_data(data: Dictionary) -> void:
	ore = maxi(int(data.get("ore", 0)), 0)
	fuel = maxi(int(data.get("fuel", 0)), 0)
	ingots = maxi(int(data.get("ingots", 0)), 0)
	progress = clampf(float(data.get("progress", 0.0)), 0.0, smelt_time)
	_update_fire()


func _status_line() -> String:
	if is_burning():
		var left := int(ceil(smelt_time - progress))
		return "Fundindo… (%d minério, %d lenha) — próximo lingote em %ds" % [ore, fuel, left]
	if ore > 0 or fuel > 0:
		return "Fornalha parada (%d minério, %d lenha)" % [ore, fuel]
	return "Fornalha vazia: traga minério de ferro e madeira"


func _update_fire() -> void:
	var burning := is_burning() and piece_id != &""
	if _glow != null:
		_glow.visible = burning
	if _light != null:
		_light.visible = burning
	if _fear != null:
		_fear.visible = burning
	if _smoke != null:
		_smoke.emitting = burning
