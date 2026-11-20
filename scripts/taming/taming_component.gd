class_name TamingComponent
extends Node
## Confiança, medo e intervalo de uma criatura selvagem. Não move nada e não desenha nada:
## recebe "o jogador está sendo agressivo?" e "tentaram alimentar" e emite eventos.

signal trust_changed(value: float, max_value: float)
signal fear_changed(value: float)
signal fed(food_id: StringName, gain: float)
signal feed_rejected(reason: StringName)
signal scared
signal bond_completed

const REASON_REQUIREMENTS := &"requirements_not_met"
const REASON_TOO_FAR := &"too_far"
const REASON_COOLDOWN := &"cooldown"
const REASON_SCARED := &"scared"
const REASON_NO_ITEM := &"no_item"
const REASON_BONDED := &"already_bonded"

@export var profile: TamingProfile

var trust: float = 0.0
var fear: float = 0.0
var bonded := false
var cooldown_left := 0.0
var _aggressive_wait := 0.0
var _fleeing := false


## Avança o tempo. aggressive = jogador correndo dentro do raio de alerta.
func tick(delta: float, aggressive: bool) -> void:
	if bonded or profile == null:
		return
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_aggressive_wait = maxf(_aggressive_wait - delta, 0.0)
	if aggressive:
		if _aggressive_wait <= 0.0:
			_aggressive_wait = profile.aggressive_interval
			_set_fear(fear + profile.aggressive_fear)
	else:
		_set_fear(fear - profile.fear_decay_per_second * delta)
	if fear > profile.flee_threshold and not _fleeing:
		_fleeing = true
		_set_trust(trust - profile.scare_trust_penalty)
		scared.emit()
	elif _fleeing and fear <= profile.accept_fear_max:
		_fleeing = false


func is_fleeing() -> bool:
	return _fleeing


## Comida aceita do inventário (preferida primeiro). &"" se não tiver nenhuma.
func food_in(inventory: Inventory) -> StringName:
	if inventory == null or profile == null:
		return &""
	for id in profile.preferred_foods:
		if inventory.has_item(id):
			return id
	for id in profile.acceptable_foods:
		if inventory.has_item(id):
			return id
	return &""


## Motivo pelo qual a alimentação seria recusada agora, ou &"" se seria aceita.
func check_feed(inventory: Inventory, distance: float, requirements_ok: bool = true) -> StringName:
	if bonded:
		return REASON_BONDED
	if not requirements_ok:
		return REASON_REQUIREMENTS
	if distance > profile.interaction_distance:
		return REASON_TOO_FAR
	if cooldown_left > 0.0:
		return REASON_COOLDOWN
	if _fleeing or fear > profile.accept_fear_max:
		return REASON_SCARED
	if food_in(inventory) == &"":
		return REASON_NO_ITEM
	return &""


## Tenta alimentar. Valida tudo antes de consumir; recusa não consome nem reinicia o intervalo.
func try_feed(inventory: Inventory, distance: float, requirements_ok: bool = true) -> Dictionary:
	var reason := check_feed(inventory, distance, requirements_ok)
	if reason != &"":
		feed_rejected.emit(reason)
		return {"ok": false, "reason": reason}
	var food := food_in(inventory)
	if not inventory.remove_item(food, 1):
		feed_rejected.emit(REASON_NO_ITEM)
		return {"ok": false, "reason": REASON_NO_ITEM}
	var gain := profile.preferred_gain if profile.preferred_foods.has(food) else profile.acceptable_gain
	cooldown_left = profile.feed_cooldown
	_set_trust(trust + gain)
	fed.emit(food, gain)
	if trust >= profile.max_trust:
		bonded = true
		bond_completed.emit()
	return {"ok": true, "food": food, "gain": gain, "bonded": bonded}


## Para o save de companheiros (selvagens não guardam confiança no MVP).
func force_bonded() -> void:
	bonded = true
	trust = profile.max_trust if profile != null else 100.0
	fear = 0.0
	_fleeing = false


func _set_trust(value: float) -> void:
	var clamped := clampf(value, 0.0, profile.max_trust)
	if not is_equal_approx(clamped, trust):
		trust = clamped
		trust_changed.emit(trust, profile.max_trust)


func _set_fear(value: float) -> void:
	var clamped := clampf(value, 0.0, 100.0)
	if clamped != fear:
		fear = clamped
		fear_changed.emit(fear)
