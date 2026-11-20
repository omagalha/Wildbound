class_name LevelHUD
extends CanvasLayer
## Nível, barra de XP, preset atual e avisos de subida de nível. Só escuta sinais.

@export var level_manager: LevelManager
@export var experience: ExperienceComponent
@export var difficulty: DifficultyManager
@export var day_night: DayNightCycle
@export var notice_duration: float = 4.0
## Para mostrar em que zona o jogador está.
@export var player: Node3D

@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: ProgressBar = %XPBar
@onready var _notice_label: Label = %NoticeLabel
@onready var _difficulty_label: Label = %DifficultyLabel
@onready var _zone_label: Label = %ZoneLabel
@onready var _clock_label: Label = %ClockLabel
var _zone_check := 0.0

var _notice_left := 0.0


func _ready() -> void:
	if day_night != null:
		day_night.set_builtin_clock_visible(false)
	if experience != null:
		experience.xp_changed.connect(func(_t): _refresh())
	if level_manager != null:
		level_manager.level_up.connect(_on_level_up)
	if difficulty != null:
		difficulty.settings_applied.connect(func(_s): _refresh())
	_notice_label.text = ""
	_refresh()
	_update_world_info()


func _process(delta: float) -> void:
	_zone_check -= delta
	if _zone_check <= 0.0:
		_zone_check = 0.25
		_update_world_info()
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice_label.text = ""


func get_level_text() -> String:
	return _level_label.text


func get_zone_text() -> String:
	return _zone_label.text


func get_clock_text() -> String:
	return _clock_label.text


func _update_world_info() -> void:
	_update_zone()
	_clock_label.text = day_night.clock_text() if day_night != null else ""


func _update_zone() -> void:
	if player == null:
		_zone_label.text = ""
		return
	var zone := TerritoryZone.zone_at(get_tree(), player.global_position)
	if zone == null:
		_zone_label.text = "Mata aberta"
		_zone_label.modulate = Color(0.9, 0.9, 0.9)
	else:
		_zone_label.text = "%s · %s" % [zone.level_text(), zone.zone_name]
		_zone_label.modulate = Color(0.6, 1, 0.65) if zone.level == TerritoryZone.Level.SAFE else Color(1, 0.6, 0.45)


func get_notice() -> String:
	return _notice_label.text


func _refresh() -> void:
	if level_manager == null or level_manager.curve == null:
		return
	var level := level_manager.level
	var name := level_manager.curve.level_name(level)
	if level_manager.is_max_level():
		_level_label.text = "Nível %d — %s (máximo do MVP)" % [level, name]
		_xp_bar.max_value = 1
		_xp_bar.value = 1
	else:
		var into := level_manager.xp_into_level()
		var needed := level_manager.xp_needed_for_next()
		_level_label.text = "Nível %d — %s · %d/%d XP" % [level, name, into, needed]
		_xp_bar.max_value = needed
		_xp_bar.value = into
	if difficulty != null and difficulty.current != null:
		_difficulty_label.text = difficulty.current.display_name


func _on_level_up(new_level: int, level_name: String, unlocked: Array) -> void:
	var names := unlocked.map(func(id): return level_manager.curve.knowledge_name(id))
	var text := "Nível %d — %s!" % [new_level, level_name]
	if not names.is_empty():
		text += "\nLiberado: " + ", ".join(names)
	_notice_label.text = text
	_notice_left = notice_duration
	_refresh()
