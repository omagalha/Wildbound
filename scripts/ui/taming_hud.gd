class_name TamingHUD
extends CanvasLayer
## Painel da domesticação: nome + situação, confiança e uma dica. Só lê; nunca altera o jogo.
## Aparece quando o jogador está perto de uma criatura selvagem; para companheiros mostra a ordem.

@export var creatures_root: Node
@export var player: Node3D
@export var show_radius: float = 12.0

@onready var _panel: Control = %Panel
@onready var _title: Label = %Title
@onready var _trust_bar: ProgressBar = %TrustBar
@onready var _hint: Label = %Hint

var _watched: CreatureController = null


func _process(_delta: float) -> void:
	_watched = _nearest()
	if _watched == null:
		_panel.visible = false
		return
	_panel.visible = true
	var c := _watched
	var name := c.definition.display_name.to_upper()
	if c.is_companion():
		_title.text = "%s · COMPANHEIRO" % name
		_trust_bar.visible = false
		_hint.text = ("Seguindo você — o Instinto Selvagem aponta recursos ✦" if c.is_following()
			else "Parado aqui — [E] perto dele para chamar")
		return
	_title.text = "%s SELVAGEM · %s" % [name, c.state_name()]
	_trust_bar.visible = true
	_trust_bar.value = c.taming.trust
	_hint.text = hint_for(c)


func get_title() -> String:
	return _title.text if _panel.visible else ""


func get_hint() -> String:
	return _hint.text if _panel.visible else ""


func hint_for(c: CreatureController) -> String:
	var t := c.taming
	if t.is_fleeing() or c.state == CreatureController.State.SCARED:
		return "Você assustou! Espere ele se acalmar e chegue andando (sem Shift)"
	if t.fear > t.profile.accept_fear_max:
		return "Desconfiado… fique parado um pouco"
	if not c.requirements_ok():
		return "Você ainda não sabe criar vínculos"
	var inventory: Inventory = player.get_node_or_null("Inventory") if player != null else null
	if t.food_in(inventory) == &"":
		return "Ele gosta de frutas silvestres — colha nos arbustos"
	if t.cooldown_left > 0.0:
		return "Mastigando… espere %d s" % ceili(t.cooldown_left)
	if c.distance_to_player() > t.profile.interaction_distance + 0.6:
		return "Aproxime-se devagar"
	return "[E] Oferecer frutas"


func _nearest() -> CreatureController:
	if creatures_root == null or player == null:
		return null
	var best: CreatureController = null
	var best_distance := show_radius
	for node in creatures_root.get_children():
		var c := node as CreatureController
		if c == null:
			continue
		var d := c.global_position.distance_to(player.global_position)
		var limit := show_radius if c.is_wild() else 6.0
		if d <= limit and d < best_distance:
			best = c
			best_distance = d
	return best
