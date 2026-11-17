extends Node3D
## Entry point. Builds the environment, then hands control to MatchManager.
## Kept tiny on purpose: everything testable lives in its own system script.

var match_manager: MatchManager
var hud: HUD
var touch: TouchControls
var menu: MainMenu
var environment: WorldEnvironment
var sun: DirectionalLight3D


func _ready() -> void:
	_build_environment()
	match_manager = MatchManager.new()
	match_manager.name = "MatchManager"
	add_child(match_manager)

	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.bind(match_manager)

	touch = TouchControls.new()
	touch.name = "TouchControls"
	add_child(touch)
	touch.bind(match_manager)

	menu = MainMenu.new()
	menu.name = "Menu"
	add_child(menu)
	menu.deploy_requested.connect(_on_deploy_requested)
	menu.restart_requested.connect(_on_restart_requested)
	match_manager.match_ended.connect(_on_match_ended)
	menu.show_menu()
	GameState.apply_quality()
	if "--smoke" in OS.get_cmdline_user_args():
		_run_smoke_test()


func _run_smoke_test() -> void:
	## CI smoke test: drop the bot count, deploy automatically, let the match run
	## for a few hundred frames and fail the build on any engine error.
	GameState.settings["bot_count"] = 39
	await get_tree().process_frame
	await get_tree().process_frame
	_on_deploy_requested()
	Engine.time_scale = 5.0
	if match_manager.player != null:
		# The smoke dummy stands still in the open; make it unkillable so the
		# test can reach the end of a full match instead of dying at 20 s.
		match_manager.player.max_health = 100000.0
		match_manager.player.health = 100000.0
	print("SMOKE: match started, seed=", match_manager.seed_value)
	for i in 9000:
		await get_tree().process_frame
		if match_manager.state == MatchManager.State.ENDED:
			print("SMOKE: match ended at t=%.1fs, alive=%d" % [match_manager.match_time, match_manager.alive_count])
			break
		if i % 600 == 0:
			var mm := match_manager
			var p := mm.player
			var states := {}
			var with_target := 0
			var moving := 0
			for b in mm.bots:
				var bot := b as Bot
				states[bot.state] = int(states.get(bot.state, 0)) + 1
				if bot.target != null:
					with_target += 1
				if Vector2(bot.velocity.x, bot.velocity.z).length() > 0.5:
					moving += 1
			var los_fail := 0
			var fired := 0
			var dmg := 0.0
			var noammo := 0
			for b in mm.bots:
				los_fail += (b as Bot).dbg_los_fail
				fired += (b as Bot).dbg_fired
				dmg += (b as Bot).dbg_damage
				noammo += (b as Bot).dbg_noammo
			print("SMOKE bots states=", states, " with_target=", with_target, " moving=", moving,
				" los_fail=", los_fail, " fired=", fired, " dmg=", dmg, " noammo=", noammo)
			print("SMOKE t=%.1fs state=%d alive=%d player_y=%.1f hp=%.0f zone_r=%.0f phase=%d loot=%d" % [
				mm.match_time, mm.state, mm.alive_count,
				p.global_position.y if p != null else -1.0,
				p.health if p != null else -1.0,
				mm.zone.radius if mm.zone != null else -1.0,
				mm.zone.phase_index if mm.zone != null else -1,
				mm.loot.spawned if mm.loot != null else -1,
			])
	print("SMOKE: done, kills=%d" % (match_manager.player.kills if match_manager.player != null else -1))
	get_tree().quit(0)


func _build_environment() -> void:
	environment = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.19, 0.26, 0.32)
	sky_mat.sky_horizon_color = Color(0.46, 0.48, 0.47)
	sky_mat.ground_bottom_color = Color(0.08, 0.09, 0.09)
	sky_mat.ground_horizon_color = Color(0.30, 0.31, 0.29)
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.40, 0.43, 0.44)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.4
	env.ssao_enabled = false
	env.glow_enabled = false
	environment.environment = env
	add_child(environment)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, 38, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = float(GameState.quality()["shadow_distance"])
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


func _on_deploy_requested() -> void:
	menu.hide_menu()
	hud.show_hud()
	match_manager.start_match()


func _on_restart_requested() -> void:
	match_manager.teardown()
	await get_tree().process_frame
	_on_deploy_requested()


func _on_match_ended(result: Dictionary) -> void:
	hud.show_result(result)
	menu.show_result(result)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		menu.toggle_pause()
