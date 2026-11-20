class_name DamageInfo
extends RefCounted
## Pacote de dano comum a todas as fontes (GDD 004, GDD 006, GDD 007).
##
## Todo dano declara uma causa. Um pacote sem causa é inválido e não é aplicado:
## isso é a base da regra "falha técnica nunca é morte" do Hardcore.

const CAUSE_STARVATION := &"starvation"

var amount: float = 0.0
## "physical", "starvation" ou uma afinidade ("fire", "nature"...).
var damage_type: StringName = &"physical"
## Causa registrada na morte: "starvation", "enemy:<id>", "fall", "environment:<id>"...
var cause: StringName = &""
var source: Node = null


static func create(p_amount: float, p_cause: StringName, p_type: StringName = &"physical", p_source: Node = null) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = p_amount
	info.cause = p_cause
	info.damage_type = p_type
	info.source = p_source
	return info


func is_valid() -> bool:
	return amount > 0.0 and cause != &""
