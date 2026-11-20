class_name SaveManager
extends Node
## Save base (WLD-019): gravação transacional, validação, cópia de segurança,
## autosave e carregamento do jogador, inventário, construções e recursos.
##
## Segue HARDCORE_LEGACY.md 4 (partes que valem para todos os modos):
##   1. grava em <slot>.tmp;  2. relê e valida;  3. o atual vira <slot>.bak;
##   4. o .tmp vira o atual.  Uma interrupção em qualquer passo deixa um arquivo íntegro.
## Formato JSON com versão e soma de verificação (SHA-256) do conteúdo — detecta
## arquivo truncado ou corrompido; não é proteção contra edição manual.
##
## Ainda NÃO há: perfil geral, estado do Hardcore, menu de jogos salvos. O nó vive
## na cena principal (sem autoload — pendência P-HC-01).

signal saved(path: String)
signal loaded(path: String)
signal save_failed(reason: String)
signal load_status(status: StringName)  # "loaded", "no_save", "corrupted"

const FORMAT_VERSION := 1
const STATUS_LOADED := &"loaded"
const STATUS_NO_SAVE := &"no_save"
const STATUS_CORRUPTED := &"corrupted"

@export var save_dir: String = "user://saves"
@export var slot_name: String = "world"
## Intervalo do autosave, em segundos de jogo. 0 = desligado.
@export var autosave_interval: float = 60.0
@export var load_on_start: bool = true

@export var player: CharacterBody3D
@export var health: HealthComponent
@export var hunger: HungerComponent
@export var inventory: Inventory
@export var building_manager: BuildingManager
@export var respawn: SimpleRespawn
## Nó cujos descendentes ResourceNode são salvos (pelo caminho relativo).
@export var resources_root: Node
@export var spawn_point: Node3D
@export var difficulty: DifficultyManager
@export var experience: ExperienceComponent
@export var level_manager: LevelManager
@export var knowledge: KnowledgeManager
## Criaturas (CreatureController) filhas diretas; só companheiros são gravados.
@export var creatures_root: Node
## Relógio do mundo (dia e hora); opcional.
@export var day_night: DayNightCycle
## Hotbar e item na mão; opcional.
@export var equipment: PlayerEquipment

var _autosave_left := 0.0
var _loading := false


func _ready() -> void:
	_autosave_left = autosave_interval
	if respawn != null:
		# Gravação única depois da morte: jogador vivo, inventário vazio e mochila no mundo.
		respawn.player_respawned.connect(func(): save_game())
	if load_on_start:
		load_game.call_deferred()


func _physics_process(delta: float) -> void:
	if autosave_interval <= 0.0 or _loading:
		return
	_autosave_left -= delta
	if _autosave_left <= 0.0:
		_autosave_left = autosave_interval
		save_game()


func _notification(what: int) -> void:
	# Salvar ao fechar a janela (PC) e ao ir para segundo plano (iOS).
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func main_path() -> String:
	return save_dir.path_join(slot_name + ".json")


func tmp_path() -> String:
	return main_path() + ".tmp"


func bak_path() -> String:
	return main_path() + ".bak"


# ---------- salvar ----------

## Grava o estado atual. Devolve true se gravou.
func save_game() -> bool:
	if _loading:
		return false
	if health != null and health.is_dead():
		# Morto aguardando respawn: o último estado vivo continua valendo.
		return false
	var payload_text := JSON.stringify(collect_state(), "", true)
	var document := JSON.stringify({
		"format_version": FORMAT_VERSION,
		"checksum": payload_text.sha256_text(),
		"payload": payload_text,
	})
	DirAccess.make_dir_recursive_absolute(save_dir)
	var file := FileAccess.open(tmp_path(), FileAccess.WRITE)
	if file == null:
		return _fail("Não foi possível escrever o arquivo temporário")
	file.store_string(document)
	file.close()
	if parse_document(_read_text(tmp_path())).is_empty():
		DirAccess.remove_absolute(tmp_path())
		return _fail("O arquivo gravado não passou na validação")
	if FileAccess.file_exists(main_path()):
		if parse_document(_read_text(main_path())).is_empty():
			# O atual está corrompido: não pode virar a cópia de segurança (a boa seria perdida).
			# Fica guardado como .corrupt para diagnóstico.
			if FileAccess.file_exists(main_path() + ".corrupt"):
				DirAccess.remove_absolute(main_path() + ".corrupt")
			DirAccess.rename_absolute(main_path(), main_path() + ".corrupt")
		else:
			if FileAccess.file_exists(bak_path()):
				DirAccess.remove_absolute(bak_path())
			if DirAccess.rename_absolute(main_path(), bak_path()) != OK:
				return _fail("Não foi possível criar a cópia de segurança")
	if DirAccess.rename_absolute(tmp_path(), main_path()) != OK:
		return _fail("Não foi possível substituir o save")
	saved.emit(main_path())
	return true


## Estado do jogo como dicionário (sem referências a nós).
func collect_state() -> Dictionary:
	var state := {"saved_at_unix": Time.get_unix_time_from_system()}
	if player != null:
		state["player"] = {
			"position": _vec_to_array(player.global_position),
			"health": health.current_health if health != null else 100.0,
			"hunger": hunger.current_hunger if hunger != null else 100.0,
		}
	if inventory != null:
		var items := {}
		var all := inventory.get_all()
		for id in all:
			items[String(id)] = all[id]
		state["inventory"] = items
	if building_manager != null:
		var pieces := []
		for piece in building_manager.get_pieces():
			var entry := {
				"id": String(piece.piece_id),
				"definition": String(piece.definition.id),
				"transform": _transform_to_array(piece.global_transform),
				"support": String(piece.support_id),
			}
			if piece.has_method("get_piece_data"):
				entry["data"] = piece.get_piece_data()
			pieces.append(entry)
		state["building"] = {
			"pieces": pieces,
			"active_bed": String(respawn.active_bed.piece_id) if respawn != null and respawn.active_bed != null and is_instance_valid(respawn.active_bed) else "",
		}
	if difficulty != null:
		state["difficulty"] = difficulty.get_save_data()
	if experience != null:
		var known := {}
		if knowledge != null:
			var all := knowledge.get_all()
			for id in all:
				known[String(id)] = String(all[id])
		state["progression"] = {"experience": experience.get_save_data(), "knowledge": known}
	if respawn != null:
		state["bags"] = respawn.get_bags_data()
	if creatures_root != null:
		var creatures := {}
		for node in creatures_root.get_children():
			if node is CreatureController:
				var data: Dictionary = node.get_save_data()
				if not data.is_empty():
					creatures[String(node.name)] = data
		state["creatures"] = creatures
	if resources_root != null:
		var nodes := {}
		for node in resources_root.find_children("*", "ResourceNode", true, false):
			nodes[String(resources_root.get_path_to(node))] = (node as ResourceNode).get_save_data()
		state["resources"] = nodes
	if day_night != null:
		state["world_time"] = day_night.get_save_data()
	var camps := {}
	for node in get_tree().get_nodes_in_group(&"abandoned_camps"):
		if node.has_method("get_save_data"):
			camps[String(node.name)] = node.get_save_data()
	if not camps.is_empty():
		state["camps"] = camps
	if equipment != null:
		state["hotbar"] = equipment.get_save_data()
	return state


# ---------- carregar ----------

## Carrega o melhor arquivo íntegro: atual → temporário → cópia de segurança.
## Nunca apaga arquivos corrompidos (ficam para diagnóstico).
func load_game() -> StringName:
	var found_any := false
	for path in [main_path(), tmp_path(), bak_path()]:
		if not FileAccess.file_exists(path):
			continue
		found_any = true
		var state := parse_document(_read_text(path))
		if state.is_empty():
			push_warning("SaveManager: '%s' inválido ou corrompido; tentando o próximo." % path)
			continue
		await apply_state(state)
		if path == tmp_path():
			# Gravação interrompida depois de validar: o .tmp vira o atual.
			if FileAccess.file_exists(main_path()):
				DirAccess.remove_absolute(main_path())
			DirAccess.rename_absolute(tmp_path(), main_path())
		elif FileAccess.file_exists(tmp_path()):
			DirAccess.remove_absolute(tmp_path())
		loaded.emit(path)
		load_status.emit(STATUS_LOADED)
		return STATUS_LOADED
	var status := STATUS_CORRUPTED if found_any else STATUS_NO_SAVE
	if status == STATUS_CORRUPTED:
		push_warning("SaveManager: nenhum save íntegro; o jogo começa do zero e os arquivos foram mantidos.")
	load_status.emit(status)
	return status


## Valida o documento e devolve o estado, ou {} se for inválido.
func parse_document(text: String) -> Dictionary:
	if text.is_empty():
		return {}
	var document = JSON.parse_string(text)
	if typeof(document) != TYPE_DICTIONARY:
		return {}
	if int(document.get("format_version", -1)) != FORMAT_VERSION:
		return {}
	var payload_text = document.get("payload")
	if typeof(payload_text) != TYPE_STRING or payload_text.sha256_text() != document.get("checksum", ""):
		return {}
	var state = JSON.parse_string(payload_text)
	if typeof(state) != TYPE_DICTIONARY or not _state_is_sane(state):
		return {}
	return state


## Aplica um estado já validado. Proteção de carregamento: sem dano e sem fome
## até o mundo assentar (versão simples de HARDCORE_LEGACY.md 5.2).
func apply_state(state: Dictionary) -> void:
	_loading = true
	if health != null:
		health.accepts_damage = false
	if hunger != null:
		hunger.active = false

	if typeof(state.get("camps")) == TYPE_DICTIONARY:
		for node in get_tree().get_nodes_in_group(&"abandoned_camps"):
			var saved = state["camps"].get(String(node.name))
			if typeof(saved) == TYPE_DICTIONARY:
				node.apply_save_data(saved)

	if day_night != null and typeof(state.get("world_time")) == TYPE_DICTIONARY:
		day_night.apply_save_data(state["world_time"])

	if difficulty != null and state.has("difficulty"):
		difficulty.restore(StringName(state["difficulty"].get("preset_id", "")))

	if experience != null and state.has("progression"):
		var progression: Dictionary = state["progression"]
		if knowledge != null:
			knowledge.restore(progression.get("knowledge", {}))
		var xp := int(progression.get("experience", {}).get("total_xp", 0))
		if level_manager != null:
			level_manager.sync_to_xp(xp)  # antes de restaurar o XP: carregar não dispara "subiu de nível"
		experience.restore(progression.get("experience", {}))

	# Inventário depois da progressão: a capacidade pode depender de conhecimentos.
	if inventory != null and state.has("inventory"):
		inventory.load_counts(state["inventory"])
	if equipment != null and typeof(state.get("hotbar")) == TYPE_DICTIONARY:
		equipment.apply_save_data(state["hotbar"])

	if respawn != null and state.has("bags"):
		respawn.restore_bags(state["bags"])

	if building_manager != null and state.has("building"):
		building_manager.clear_all()
		var bed_id := StringName(state["building"].get("active_bed", ""))
		for entry in state["building"].get("pieces", []):
			var definition := building_manager.get_definition(StringName(entry.get("definition", "")))
			if definition == null:
				push_warning("SaveManager: peça '%s' com definição desconhecida foi ignorada." % entry.get("id", "?"))
				continue
			var piece := building_manager.restore_piece(definition, _array_to_transform(entry["transform"]), StringName(entry["id"]), StringName(entry.get("support", "")))
			if piece != null and piece.has_method("apply_piece_data") and typeof(entry.get("data")) == TYPE_DICTIONARY:
				piece.apply_piece_data(entry["data"])
			if piece != null and piece is SurvivalBed and piece.piece_id == bed_id and respawn != null:
				respawn.set_active_bed(piece)

	if creatures_root != null and state.has("creatures"):
		for creature_name in state["creatures"]:
			var creature := creatures_root.get_node_or_null(NodePath(creature_name)) as CreatureController
			if creature != null:
				creature.apply_save_data(state["creatures"][creature_name])
	if resources_root != null and state.has("resources"):
		for path in state["resources"]:
			var node := resources_root.get_node_or_null(NodePath(path)) as ResourceNode
			if node != null:
				node.apply_save_data(state["resources"][path])

	if player != null and state.has("player"):
		var data: Dictionary = state["player"]
		player.velocity = Vector3.ZERO
		player.global_position = _array_to_vec(data["position"])
		if hunger != null:
			hunger.set_hunger(float(data.get("hunger", hunger.max_hunger)))
		if health != null:
			health.current_health = clampf(float(data.get("health", health.max_health)), 1.0, health.max_health)
			health.health_changed.emit(health.current_health, health.max_health)

	await get_tree().physics_frame
	await get_tree().physics_frame
	_validate_player_position()
	if health != null:
		health.accepts_damage = true
	if hunger != null:
		hunger.active = true
	_autosave_left = autosave_interval
	_loading = false


func is_loading() -> bool:
	return _loading


# ---------- utilidades ----------

func _validate_player_position() -> void:
	if player == null:
		return
	var space := player.get_world_3d().direct_space_state
	var from := player.global_position + Vector3.UP * 1.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0, 1))
	if hit.is_empty() and spawn_point != null:
		push_warning("SaveManager: posição salva sem chão; jogador levado ao ponto inicial.")
		player.global_position = spawn_point.global_position
		player.velocity = Vector3.ZERO


func _state_is_sane(state: Dictionary) -> bool:
	if state.has("player"):
		var p = state["player"]
		if typeof(p) != TYPE_DICTIONARY or not _is_vec_array(p.get("position")):
			return false
		var hp := float(p.get("health", -1.0))
		var food := float(p.get("hunger", -1.0))
		if hp < 0.0 or hp > 10000.0 or food < 0.0 or food > 100.0:
			return false
	if state.has("inventory") and typeof(state["inventory"]) != TYPE_DICTIONARY:
		return false
	if state.has("building"):
		var b = state["building"]
		if typeof(b) != TYPE_DICTIONARY or typeof(b.get("pieces", [])) != TYPE_ARRAY:
			return false
		for entry in b.get("pieces", []):
			if typeof(entry) != TYPE_DICTIONARY or not entry.has("id") or typeof(entry.get("transform")) != TYPE_ARRAY or entry["transform"].size() != 12:
				return false
	return true


func _is_vec_array(value) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return false
	for v in value:
		if typeof(v) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(v)):
			return false
	return true


func _read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _fail(reason: String) -> bool:
	push_warning("SaveManager: " + reason)
	save_failed.emit(reason)
	return false


static func _vec_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _array_to_vec(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _transform_to_array(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
		t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]


static func _array_to_transform(a: Array) -> Transform3D:
	var f := a.map(func(v): return float(v))
	return Transform3D(Vector3(f[0], f[1], f[2]), Vector3(f[3], f[4], f[5]), Vector3(f[6], f[7], f[8]), Vector3(f[9], f[10], f[11]))
