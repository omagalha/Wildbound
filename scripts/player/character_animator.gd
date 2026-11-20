class_name CharacterAnimator
extends Node
## Troca a cápsula provisória por um personagem animado (Quaternius) e escolhe
## a animação conforme o estado do jogador.
##
## O modelo e as bibliotecas de animação compartilham o mesmo esqueleto
## (ossos "root", "pelvis", "hand_r"...), então as animações das bibliotecas
## tocam direto no modelo. A arma e a tocha seguem as mãos por
## RemoteTransform3D, sem sair do lugar na árvore (os outros sistemas e os
## testes continuam achando "Visual/Weapon/Club" e "Visual/Torch").
##
## Locomoção: parado, andando (trote), correndo, no ar. Ações de uma vez:
## golpe, dano, comer, coletar, cortar árvore, pegar do chão, morrer.

## Modelo do personagem (glTF com Armature/Skeleton3D). Vazio = mantém a cápsula.
@export var model_scene: PackedScene
## Roupa vestida por cima do corpo (Modular Character Outfits). Vazio = sem roupa.
## As malhas da roupa passam a usar o esqueleto do modelo, então seguem as animações.
@export var outfit_scene: PackedScene
## Bibliotecas de animação com o mesmo esqueleto (UAL1, UAL2).
@export var animation_sources: Array[PackedScene] = []
@export var player: PlayerController
@export var health: HealthComponent
@export var weapon: WeaponController
@export var food: FoodConsumer
@export var interaction: InteractionDetector
## Velocidade (m/s) em que o trote e a corrida tocam em ritmo normal.
@export var jog_reference_speed: float = 4.2
@export var sprint_reference_speed: float = 7.0
@export var blend_time: float = 0.15

## Nome no jogo -> nome na biblioteca.
const CLIPS := {
	"idle": "Idle", "idle_armed": "Sword_Idle", "idle_torch": "Idle_Torch", "jog": "Jog_Fwd", "sprint": "Sprint",
	"air": "Jump", "attack": "Sword_Regular_A", "attack_heavy": "Sword_Attack",
	"hit": "Hit_Chest", "death": "Death01", "eat": "Consume", "harvest": "Farm_Harvest",
	"chop": "TreeChopping", "pickup": "PickUp_Table", "interact": "Interact",
	"cast": "Spell_Simple_Shoot", "swim": "Swim_Fwd", "swim_idle": "Swim_Idle",
}
const ONE_SHOT_PRIORITY := {"death": 10, "attack": 5, "attack_heavy": 5, "chop": 5, "cast": 5, "hit": 3, "eat": 2, "harvest": 2, "pickup": 2, "interact": 2}

## Pegada da mão direita. Ferramentas são montadas com o cabo em +Y e a
## frente (lâmina, ponta) em -X; no osso da mão, +Y aponta para os dedos e -X
## para o lado do polegar. Então: cabo atravessa o punho saindo pelo polegar,
## e a lâmina fica virada para o lado dos dedos, como numa pegada de verdade.
const RIGHT_GRIP := Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5) * Basis(Vector3(0, 1, 0), PI), Vector3(0.0, 0.08, 0.0))

static var _clip_cache := {}  # caminho da biblioteca -> {nome: Animation}

var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var current := ""
var _one_shot := ""
var _one_shot_left := 0.0
var _visual: Node3D
var _right_hand: RemoteTransform3D
var _left_hand: RemoteTransform3D


func _ready() -> void:
	if model_scene == null or player == null:
		return
	_visual = player.visual
	model = model_scene.instantiate() as Node3D
	model.name = "Model"
	model.rotation.y = PI  # o modelo olha para +Z; o Visual do jogador, para -Z
	_visual.add_child(model)
	for old in ["MeshInstance3D", "FacingIndicator"]:
		var node := _visual.get_node_or_null(old) as Node3D
		if node != null:
			node.visible = false
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	wear_outfit(outfit_scene)
	_build_animation_player()
	_attach_hands()
	if weapon != null:
		weapon.procedural_swing = false
		weapon.swung.connect(_on_swung)
	if health != null:
		health.damaged.connect(_on_damaged)
		health.died.connect(func(_c): _play_once("death"))
		health.revived.connect(func(_h): _clear_one_shot())
	if food != null:
		food.eat_result.connect(func(ok, _r, _i): if ok: _play_once("eat"))
	if interaction != null:
		interaction.interacted.connect(_on_interacted)
	_play("idle")
	_attach_torch.call_deferred()


func _physics_process(delta: float) -> void:
	if anim == null:
		return
	if _one_shot != "":
		_one_shot_left -= delta
		var moving := _flat_speed() > 1.5
		# Ações curtas param se o jogador sai andando; golpe e morte, não.
		if _one_shot_left <= 0.0 or (moving and ONE_SHOT_PRIORITY.get(_one_shot, 0) == 2):
			if _one_shot == "death":
				return  # fica caído até reviver
			_clear_one_shot()
		else:
			return
	_update_locomotion()


## Animação de lançar magia (chamada pelo AbilityController).
func play_cast() -> void:
	_play_once("cast", 0.6)


## Veste uma roupa: move as malhas dela para o esqueleto do personagem.
## Devolve quantas peças foram vestidas. Chamar de novo troca a roupa.
func wear_outfit(scene: PackedScene) -> int:
	if skeleton == null:
		return 0
	for old in skeleton.get_children():
		if old.has_meta(&"outfit_part"):
			old.queue_free()
	_show_head_only(scene != null)
	if scene == null:
		return 0
	var outfit := scene.instantiate()
	var count := 0
	for node in outfit.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.get_parent().remove_child(mi)
		mi.owner = null
		mi.set_meta(&"outfit_part", true)
		skeleton.add_child(mi)
		mi.skeleton = mi.get_path_to(skeleton)
		mi.transform = Transform3D.IDENTITY
		_fix_outfit_materials(mi)
		count += 1
	outfit.free()
	return count


## Os materiais vêm exportados como 100% metálicos (canal da Unity); sem
## reflexos isso fica preto. Vira tecido/couro fosco.
func _fix_outfit_materials(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var base := mi.mesh.surface_get_material(i) as StandardMaterial3D
		if base == null:
			continue
		var mat := base.duplicate() as StandardMaterial3D
		mat.metallic = 0.0
		mat.metallic_texture = null
		mat.roughness = 0.85
		mi.set_surface_override_material(i, mat)


## Ossos cuja pele fica visível sob a roupa (o resto do corpo base some, senão
## o corpo musculoso atravessa as roupas feitas para o corpo "normal").
const HEAD_BONES := ["Head", "neck_01"]
static var _head_mesh_cache := {}  # malha original -> malha só com a cabeça
var _body_meshes := {}  # MeshInstance3D -> malha original


## Liga/desliga o "só cabeça" no corpo base (olhos e sobrancelhas ficam).
func _show_head_only(enabled: bool) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.has_meta(&"outfit_part") or mi.mesh == null or mi.skin == null:
			continue
		if not _body_meshes.has(mi):
			_body_meshes[mi] = mi.mesh
		var original: Mesh = _body_meshes[mi]
		if original.get_surface_count() == 0 or (original as ArrayMesh) == null:
			continue
		# Só o corpo (malha grande): olhos e sobrancelhas já são só cabeça.
		if original.get_aabb().size.y < 1.0:
			continue
		mi.mesh = _head_only(original, mi.skin) if enabled else original


static func _head_only(mesh: ArrayMesh, skin: Skin) -> ArrayMesh:
	if _head_mesh_cache.has(mesh):
		return _head_mesh_cache[mesh]
	var keep_binds := {}
	for b in skin.get_bind_count():
		if String(skin.get_bind_name(b)) in HEAD_BONES:
			keep_binds[b] = true
	var out := ArrayMesh.new()
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if bones.is_empty() or verts.is_empty():
			continue
		var per := bones.size() / verts.size()
		var head_vertex := PackedByteArray()
		head_vertex.resize(verts.size())
		for v in verts.size():
			var w := 0.0
			for k in per:
				if keep_binds.has(bones[v * per + k]):
					w += weights[v * per + k]
			head_vertex[v] = 1 if w > 0.5 else 0
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for t in range(0, indices.size(), 3):
			if head_vertex[indices[t]] and head_vertex[indices[t + 1]] and head_vertex[indices[t + 2]]:
				kept.append(indices[t])
				kept.append(indices[t + 1])
				kept.append(indices[t + 2])
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(surface))
	_head_mesh_cache[mesh] = out
	return out


## Tinge as peças da roupa (roupas de frio/calor).
func set_outfit_tint(color: Color) -> void:
	if skeleton == null:
		return
	for child in skeleton.get_children():
		if not child.has_meta(&"outfit_part"):
			continue
		var mi := child as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(i) as StandardMaterial3D
			if mat == null:
				continue
			if not mi.has_meta(&"base_color_%d" % i):
				mi.set_meta(&"base_color_%d" % i, mat.albedo_color)
			mat.albedo_color = (mi.get_meta(&"base_color_%d" % i) as Color) * color


func outfit_part_count() -> int:
	var n := 0
	if skeleton != null:
		for child in skeleton.get_children():
			if child.has_meta(&"outfit_part"):
				n += 1
	return n


func has_clip(game_name: String) -> bool:
	return anim != null and anim.has_animation(CLIPS.get(game_name, game_name))


## Animação tocando agora (nome do jogo: "idle", "jog", "attack"...).
func current_clip() -> String:
	return _one_shot if _one_shot != "" else current


# ---------- estados ----------

func _update_locomotion() -> void:
	if player.has_method("is_swimming") and player.is_swimming():
		_play("swim" if _flat_speed() > 0.4 else "swim_idle")
		return
	if not player.is_on_floor():
		_play("air")
		return
	var speed := _flat_speed()
	if speed < 0.4:
		if _torch_lit():
			_play("idle_torch")
		elif _holding_tool():
			_play("idle_armed")
		else:
			_play("idle")
	elif player.is_sprinting() and speed > player.walk_speed + 0.5:
		_play("sprint", clampf(speed / sprint_reference_speed, 0.8, 1.4))
	else:
		_play("jog", clampf(speed / jog_reference_speed, 0.7, 1.5))


func _on_swung() -> void:
	var interval := weapon.definition.interval if weapon.definition != null else 0.6
	var clip := "attack"
	if weapon.definition != null:
		if weapon.definition.chop_power > 0 or weapon.definition.mine_power > 0:
			clip = "chop"
		elif weapon.definition.id == &"stone_spear":
			clip = "attack_heavy"
	_play_once(clip, interval * 1.15)


func _on_damaged(_info: DamageInfo) -> void:
	if health.is_dead():
		return
	_play_once("hit")


func _on_interacted(target: Node, result: Dictionary) -> void:
	if not result.get("ok", false):
		return
	if target is ForestTree:
		_play_once("chop", 1.1)
	elif target is ResourceNode:
		match (target as ResourceNode).category:
			&"wood": _play_once("chop", 1.1)
			&"stone": _play_once("interact")
			_: _play_once("harvest")
	elif target is LootDrop:
		_play_once("pickup")
	else:
		_play_once("interact")


# ---------- reprodução ----------

func _play(game_name: String, speed: float = 1.0) -> void:
	var clip: String = CLIPS.get(game_name, game_name)
	if not anim.has_animation(clip):
		return
	# Ritmo da locomoção pelo speed_scale (muda sem reiniciar o ciclo).
	anim.speed_scale = speed
	if current != game_name:
		anim.play(clip, blend_time)
		current = game_name


## Toca uma ação uma vez. Com [param duration], ajusta a velocidade para caber nesse tempo.
func _play_once(game_name: String, duration: float = -1.0) -> void:
	var clip: String = CLIPS.get(game_name, game_name)
	if anim == null or not anim.has_animation(clip):
		return
	if _one_shot != "" and ONE_SHOT_PRIORITY.get(_one_shot, 0) > ONE_SHOT_PRIORITY.get(game_name, 0):
		return
	var length := anim.get_animation(clip).length
	var speed := 1.0
	if duration > 0.0 and length > 0.0:
		speed = clampf(length / duration, 0.6, 3.0)
	_one_shot = game_name
	_one_shot_left = length / speed
	current = ""
	anim.speed_scale = 1.0
	anim.play(clip, 0.08, speed)


func _clear_one_shot() -> void:
	_one_shot = ""
	_one_shot_left = 0.0
	current = ""


func _flat_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


## Segurando algo além da clava (machado, picareta, lança...): pose de prontidão.
func _holding_tool() -> bool:
	return weapon != null and weapon.definition != null and weapon.definition.id != &"improvised_club"


func _torch_lit() -> bool:
	var torch := _visual.get_node_or_null("Torch") as Node3D
	return torch != null and torch.visible


# ---------- montagem ----------

func _build_animation_player() -> void:
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	model.add_child(anim)
	anim.root_node = NodePath("..")
	var library := AnimationLibrary.new()
	var wanted := {}
	for key in CLIPS:
		wanted[CLIPS[key]] = true
	for source in animation_sources:
		var clips := _clips_from(source)
		for clip_name in clips:
			if wanted.has(clip_name) and not library.has_animation(clip_name):
				library.add_animation(clip_name, clips[clip_name])
	anim.add_animation_library(&"", library)


## Animações de uma biblioteca, carregadas uma vez por sessão (compartilhadas).
static func _clips_from(source: PackedScene) -> Dictionary:
	if source == null:
		return {}
	var key := source.resource_path
	if _clip_cache.has(key):
		return _clip_cache[key]
	var inst := source.instantiate()
	var out := {}
	for node in inst.find_children("*", "AnimationPlayer", true, false):
		var player_node := node as AnimationPlayer
		for clip_name in player_node.get_animation_list():
			out[String(clip_name)] = player_node.get_animation(clip_name)
	inst.free()
	_clip_cache[key] = out
	return out


func _attach_hands() -> void:
	var club := weapon.get_node_or_null("Club") as Node3D if weapon != null else null
	if club != null:
		_right_hand = _hand_remote("hand_r", club, RIGHT_GRIP)


func _attach_torch() -> void:
	var torch := _visual.get_node_or_null("Torch") as Node3D
	if torch != null and _left_hand == null:
		_left_hand = _hand_remote("hand_l", torch,
			Transform3D(Basis.from_euler(Vector3(deg_to_rad(90), 0, 0)), Vector3(0.0, 0.08, 0.0)))


func _hand_remote(bone: String, target: Node3D, offset: Transform3D) -> RemoteTransform3D:
	if skeleton.find_bone(bone) < 0:
		return null
	var attachment := BoneAttachment3D.new()
	attachment.name = "Attach_" + bone
	skeleton.add_child(attachment)
	attachment.bone_name = bone
	var remote := RemoteTransform3D.new()
	remote.name = "Holds_" + target.name
	remote.transform = offset
	remote.update_scale = false
	attachment.add_child(remote)
	remote.remote_path = remote.get_path_to(target)
	return remote
