class_name CraftingManager
extends Node
## Fabricação: valida e executa receitas sobre o inventário do jogador.
##
## A operação é atômica: ou consome todos os insumos e entrega todos os
## produtos, ou não mexe em nada. Itens únicos (pilha máxima 1, como
## ferramentas) não são fabricados de novo enquanto o jogador já tem um.

signal crafted(recipe: CraftingRecipe)
signal craft_failed(recipe: CraftingRecipe, reason: StringName)

const READY := &"ok"
const MISSING := &"missing"
const LOCKED := &"locked"
const NEEDS_STATION := &"needs_station"
const ALREADY_HAVE := &"already_have"
const NO_SPACE := &"no_space"
const DEAD := &"dead"

const STATION_PIECES := {&"campfire": &"building_campfire_primitive", &"furnace": &"building_furnace"}
const STATION_NAMES := {&"campfire": "fogueira", &"furnace": "fornalha"}

@export var recipes: Array[CraftingRecipe] = []
@export var inventory: Inventory
@export var knowledge: KnowledgeManager
@export var building_manager: BuildingManager
@export var player: Node3D
@export var health: HealthComponent
@export var experience: ExperienceComponent
## Distância máxima até a estação (fogueira).
@export var station_range: float = 3.5


func get_recipe(id: StringName) -> CraftingRecipe:
	for recipe in recipes:
		if recipe != null and recipe.id == id:
			return recipe
	return null


## Motivo pelo qual a receita pode (READY) ou não pode ser feita agora.
func status(recipe: CraftingRecipe) -> StringName:
	if recipe == null or inventory == null:
		return MISSING
	if health != null and health.is_dead():
		return DEAD
	if recipe.required_knowledge != &"" and (knowledge == null or not knowledge.is_known(recipe.required_knowledge)):
		return LOCKED
	if _already_has_unique(recipe):
		return ALREADY_HAVE
	if not inventory.has_all(_typed(recipe.inputs)):
		return MISSING
	if recipe.station != &"" and not is_near_station(recipe.station):
		return NEEDS_STATION
	if not _fits_after_consuming(recipe):
		return NO_SPACE
	return READY


func can_craft(recipe: CraftingRecipe) -> bool:
	return status(recipe) == READY


## Fabrica uma vez. Devolve {"ok": bool, "reason": StringName, "message": String}.
func craft(recipe: CraftingRecipe) -> Dictionary:
	var reason := status(recipe)
	if reason != READY:
		craft_failed.emit(recipe, reason)
		return {"ok": false, "reason": reason, "message": reason_text(recipe, reason)}
	var inputs := _typed(recipe.inputs)
	var outputs := _typed(recipe.outputs)
	if not inventory.remove_all(inputs):
		return {"ok": false, "reason": MISSING, "message": reason_text(recipe, MISSING)}
	if not inventory.add_all(outputs):
		inventory.add_all(inputs)  # devolve; nunca some item em silêncio
		return {"ok": false, "reason": NO_SPACE, "message": reason_text(recipe, NO_SPACE)}
	if experience != null and experience.rules != null:
		experience.award_first(&"recipe", recipe.id, experience.rules.first_recipe_xp)
	crafted.emit(recipe)
	return {"ok": true, "reason": READY, "message": "Fabricou: %s" % recipe.display_name}


func is_near_station(station: StringName) -> bool:
	if building_manager == null or player == null:
		return false
	var piece_id: StringName = STATION_PIECES.get(station, &"")
	for piece in building_manager.get_pieces():
		if piece.definition != null and piece.definition.id == piece_id:
			if piece.global_position.distance_to(player.global_position) <= station_range:
				return true
	return false


## Texto curto para cada motivo, como mostrado no menu e nos avisos.
func reason_text(recipe: CraftingRecipe, reason: StringName) -> String:
	match reason:
		READY:
			return "Pronto para fabricar"
		LOCKED:
			return "Bloqueado: suba de nível"
		ALREADY_HAVE:
			return "Você já tem um"
		MISSING:
			return "Faltam materiais"
		NEEDS_STATION:
			return "Precisa estar perto de uma %s" % STATION_NAMES.get(recipe.station if recipe != null else &"", "estação")
		NO_SPACE:
			return "Inventário cheio"
		DEAD:
			return ""
	return ""


## "3 Madeira · 2 Pedra" com os nomes do catálogo.
func cost_text(recipe: CraftingRecipe) -> String:
	var parts := []
	for id in recipe.inputs:
		var have := inventory.count(StringName(id)) if inventory != null else 0
		parts.append("%s %d/%d" % [_item_name(StringName(id)), have, int(recipe.inputs[id])])
	return " · ".join(parts)


func _already_has_unique(recipe: CraftingRecipe) -> bool:
	for id in recipe.outputs:
		var item := _item(StringName(id))
		if item != null and item.max_stack == 1 and inventory.has_item(item.id):
			return true
	return false


## Cabe o resultado se os insumos saírem antes? Testa sem mexer no inventário real.
func _fits_after_consuming(recipe: CraftingRecipe) -> bool:
	var probe := Inventory.new()
	probe.catalog = inventory.catalog
	probe.capacity = inventory.capacity
	probe.load_counts(inventory.get_all())
	probe.remove_all(_typed(recipe.inputs))
	var fits := probe.can_add_all(_typed(recipe.outputs))
	probe.free()
	return fits


func _typed(source: Dictionary) -> Dictionary:
	var out := {}
	for id in source:
		out[StringName(id)] = int(source[id])
	return out


func _item(id: StringName) -> ItemDefinition:
	return inventory.catalog.get_item(id) if inventory != null and inventory.catalog != null else null


func _item_name(id: StringName) -> String:
	var item := _item(id)
	return item.display_name if item != null else String(id)
