extends SceneTree
## Regressão estrutural da primeira parte do HUD para PC.

const MAIN_SCENE := "res://scenes/main/main.tscn"

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== Wildbound HUD PC: testes automatizados ==")
	var packed := load(MAIN_SCENE) as PackedScene
	_check(packed != null and packed.can_instantiate(), "Cena principal carrega")
	if packed == null:
		_finish()
		return
	var main := packed.instantiate()
	var save := main.get_node_or_null("SaveManager")
	if save != null:
		save.load_on_start = false
		save.autosave_interval = 0.0
	var difficulty := main.get_node_or_null("DifficultyManager")
	if difficulty != null:
		difficulty.ask_on_new_world = false
	root.add_child(main)
	await process_frame
	await process_frame

	var hud := main.get_node_or_null("SurvivalHUD") as SurvivalHUD
	var level_hud := main.get_node_or_null("LevelHUD") as LevelHUD
	_check(hud != null, "SurvivalHUD preservado")
	_check(level_hud != null, "LevelHUD preservado")
	if hud != null:
		await _test_main_hud(hud, main.get_node_or_null("Player") as Node3D)
	if level_hud != null:
		_check(level_hud.day_night != null, "Relógio integrado ao HUD")
		_check(level_hud.get_clock_text().begins_with("Dia "), "Dia e hora visíveis", level_hud.get_clock_text())

	main.queue_free()
	await process_frame
	_finish()


func _test_main_hud(hud: SurvivalHUD, player: Node3D) -> void:
	var minimap := hud.get_node_or_null("%Minimap") as WildboundMinimap
	var hotbar := hud.get_node_or_null("%Hotbar") as HotbarUI
	var inventory_summary := hud.get_node_or_null("%InventorySummary") as InventorySummary
	var toast_feed := hud.get_node_or_null("%ToastFeed") as HudToastFeed
	_check(minimap != null and minimap.visible, "Minimapa visível")
	_check(minimap != null and minimap.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Minimapa não bloqueia o mouse")
	_check(minimap != null and minimap.player == player, "Minimapa acompanha o jogador")
	if minimap != null and player != null:
		var center := minimap.get_map_rect().get_center()
		var marker := minimap.world_to_map(player.global_position)
		_check(marker.distance_to(center) < 0.01, "Jogador fica no centro do minimapa", str(marker))
		var east := minimap.world_to_map(player.global_position + Vector3(10.0, 0.0, 0.0))
		_check(east.x > marker.x, "Conversão X/Z do minimapa")
	_check(hotbar != null, "Hotbar de itens substitui a barra de atalhos")
	if hotbar != null:
		_check(hotbar.get_slot_count() == 9, "Hotbar tem 9 espaços (teclas 1–9)")
		_check(hotbar.get_slot_item(0) == &"improvised_club", "Espaço 1 é a clava")
		_check(hotbar.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Hotbar não bloqueia o gameplay")
	_check(inventory_summary != null, "Inventário compacto existe")
	_check(inventory_summary != null and not inventory_summary.visible, "Inventário fica escondido até apertar [I]")
	if inventory_summary != null:
		var catalog_size := (player.get_node("Inventory") as Inventory).catalog.items.size()
		_check(inventory_summary.get_item_card_count() == catalog_size,
			"Inventário tem um cartão fixo para cada item do catálogo")
		_check(inventory_summary.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Inventário compacto não bloqueia o mouse")
		_check(inventory_summary.get_card_text(&"wood") == "MAD —", "Item ausente aparece esmaecido")
		var inventory := player.get_node("Inventory") as Inventory
		inventory.add_item(&"wood", 3)
		_check(inventory_summary.get_card_text(&"wood") == "MAD 3", "Quantidade compacta atualiza por sinal")
	# Bloco de sobrevivência (canto inferior esquerdo).
	var block := hud.survival_block
	var screen := hud.get_viewport().get_visible_rect().size
	_check(block != null and block.visible, "Bloco de sobrevivência existe")
	if block != null:
		var r := block.get_global_rect()
		_check(r.position.x < screen.x * 0.2 and r.position.y < screen.y * 0.1, "Bloco no canto superior esquerdo", str(r))
		_check(block.has_portrait(), "Rosto do personagem no bloco")
		await process_frame
		await process_frame
		var version := block.portrait_version
		_check(version >= 1, "Retrato fotografado ao abrir")
		var stays := block.portrait_version
		for i in 10:
			await process_frame
		_check(block.portrait_version == stays, "Retrato parado (não refaz a cada quadro)")
		var anim := player.get_node("CharacterAnimator") as CharacterAnimator
		anim.set_outfit_tint(Color(0.9, 0.8, 0.7))
		await process_frame
		await process_frame
		await process_frame
		_check(block.portrait_version > stays, "Trocar a roupa refaz o retrato")
		var health := player.get_node("Health") as HealthComponent
		health.apply_damage(DamageInfo.create(30.0, &"enemy:test"))
		_check(block.get_health_text().begins_with("70/100") and block.get_health_text().contains("70%"), "Vida com valor e porcentagem", block.get_health_text())
		(player.get_node("Hunger") as HungerComponent).set_hunger(42.0)
		_check(block.get_hunger_text().begins_with("42/100"), "Fome com valor e porcentagem", block.get_hunger_text())
		var hotbar_rect := (hud.get_node("%Hotbar") as Control).get_global_rect()
		_check(not r.intersects(hotbar_rect.grow(-2.0)), "Bloco não cobre a barra de itens")
		var old_panel := hud.get_node_or_null("Root/TopRow/VitalsPanel") as Control
		_check(old_panel == null or not old_panel.visible, "Painel antigo do topo foi substituído")
	if minimap != null:
		_check(absf(minimap.diameter() - 160.0 * clampf(screen.y / 720.0, 0.8, 1.8)) < 0.5, "Minimapa com ~160 px a 720p (proporcional à tela)", str(minimap.diameter()))
	_check(toast_feed != null, "Feed de mensagens existe")
	if toast_feed != null:
		toast_feed.clear_all()
		hud.show_message("")
		_check(toast_feed.get_visible_count() == 0, "Mensagem vazia não apaga nem cria aviso")
		hud.show_message("Coleta concluída", 2.0, HudToastFeed.Kind.SUCCESS)
		hud.show_message("Coleta concluída", 2.0, HudToastFeed.Kind.SUCCESS)
		_check(toast_feed.get_visible_count() == 1, "Mensagens repetidas são deduplicadas")
		hud.show_message("Você morreu", 999.0, HudToastFeed.Kind.CRITICAL)
		hud.show_message("Mensagem comum", 2.0, HudToastFeed.Kind.INFO)
		_check(toast_feed.get_visible_count() == 1 and toast_feed.get_primary_text() == "Você morreu",
			"Aviso crítico não é sobrescrito")
		toast_feed.clear_all()
	var health := player.get_node("Health") as HealthComponent
	var vignette := hud.get_node("%DamageVignette") as ColorRect
	health.apply_damage(DamageInfo.create(1.0, &"enemy:hud_test"))
	_check(vignette.modulate.a > 0.9, "Dano dispara feedback visual nas bordas")
	var player_inventory := player.get_node("Inventory") as Inventory
	player_inventory.add_item(&"stone", 2)
	var bag := hud.respawn.drop_inventory_into_bag(player.global_position + Vector3(10.0, 0.0, 0.0))
	hud._update_bag_label()
	_check(bag != null and hud.get_bag_text().contains("itens") and hud.get_bag_text().contains("m"),
		"Cartão da mochila mostra itens, direção e distância", hud.get_bag_text())


func _check(condition: bool, name: String, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  [PASS] ", name)
	else:
		_failed += 1
		print("  [FAIL] ", name, (" -> " + detail) if detail != "" else "")


func _finish() -> void:
	print("== Resultado: %d passaram, %d falharam ==" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
