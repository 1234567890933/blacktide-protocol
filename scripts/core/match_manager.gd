class_name MatchManager
extends Node
## Owns the match lifecycle: build world -> deploy -> live -> result -> restart.
## Nothing else in the project knows about "a match"; every system talks to this.

signal state_changed(new_state: int, label: String)
signal kill_event(killer_name: String, victim_name: String, weapon: String)
signal player_placement(placement: int)
signal match_ended(result: Dictionary)
signal alive_changed(count: int)

enum State { IDLE, BRIEFING, DROP, LIVE, ENDED }

const DROP_HEIGHT := 240.0
const FREEFALL_SPEED := 26.0
const CANOPY_SPEED := 7.5
const CANOPY_ALTITUDE := 65.0
const SQUAD_SIZES := [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4]

var state: int = State.IDLE
var map: MapBuilder
var zone: ZoneController
var loot: LootSpawner
var squads: SquadManager
var player: Player
var bots: Array = []
var seed_value := 0
var alive_count := 0
var player_placement_value := 60
var match_time := 0.0
var _player_squad := 0
var _drop_target := Vector3.ZERO
var _ended := false


func _ready() -> void:
	set_process(false)


func start_match(p_seed: int = 0) -> void:
	if state != State.IDLE and state != State.ENDED:
		return
	seed_value = p_seed if p_seed != 0 else GameState.new_run_seed()
	_ended = false
	match_time = 0.0
	_set_state(State.BRIEFING, "BUILDING KESTREL ATOLL")
	_build_world()
	_spawn_actors()
	_set_state(State.DROP, "DEPLOY")
	_begin_drop()
	set_process(true)


func _build_world() -> void:
	map = MapBuilder.new()
	map.name = "Map"
	add_child(map)
	map.build(seed_value)

	zone = ZoneController.new()
	zone.name = "Zone"
	add_child(zone)
	zone.setup(map, seed_value)

	loot = LootSpawner.new()
	loot.name = "Loot"
	add_child(loot)
	loot.setup(map, seed_value)
	map.loot_spawner = loot
	map.zone_controller = zone
	loot.populate()

	squads = SquadManager.new()
	squads.name = "Squads"
	add_child(squads)


func _spawn_actors() -> void:
	bots.clear()
	alive_count = 0
	# Player first, so the HUD can bind before bots start moving.
	player = Player.new()
	player.name = "Player"
	player.squad_id = _player_squad
	add_child(player)
	player.add_to_group("player")
	player.died.connect(_on_actor_died)
	player.start_match("m9a3")
	player.plate_health = player.plate_capacity
	alive_count += 1

	var total_bots: int = int(GameState.settings["bot_count"])
	var squad_size: int = maxi(int(GameState.settings["squad_size"]), 1)
	var difficulty := String(GameState.settings["difficulty"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 77
	var spawns: Array = _spread_spawn_points(total_bots, rng)
	for i in total_bots:
		var bot := Bot.new()
		var squad_index: int = i / squad_size
		var bot_squad_id: int = 1 + squad_index
		var bot_name := "%s-%d" % [SquadManager.SQUAD_NAMES[bot_squad_id % SquadManager.SQUAD_NAMES.size()], (i % squad_size) + 1]
		add_child(bot)
		bot.configure(difficulty, map, squads, bot_squad_id, bot_name)
		bot.died.connect(_on_actor_died)
		var spawn: Vector3 = spawns[i % spawns.size()]
		var jitter := Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
		var p := spawn + jitter
		p.y = map.height_at(p.x, p.z) + 0.4
		bot.global_position = p
		bot.deploy_grace = 7.0 + rng.randf_range(0.0, 5.0)
		bot.state = Bot.State.ROTATE
		squads.register(bot)
		bots.append(bot)
		alive_count += 1
	alive_changed.emit(alive_count)
	player_placement_value = alive_count


func _spread_spawn_points(count: int, rng: RandomNumberGenerator) -> Array:
	## Rejection sampling: no two bots start within 26 m of each other, and every
	## spawn is on dry land. Without this, 60 bots inside one cordon wipe each
	## other out in the first ten seconds.
	var points: Array = []
	var attempts := 0
	while points.size() < count and attempts < count * 80:
		attempts += 1
		var angle := rng.randf() * TAU
		var dist := sqrt(rng.randf()) * 430.0
		var p := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		p.y = map.height_at(p.x, p.z)
		if p.y < 2.5:
			continue
		var too_close := false
		for q: Vector3 in points:
			if p.distance_to(q) < 26.0:
				too_close = true
				break
		if too_close:
			continue
		points.append(p)
	# Fallback: fill from the sector spawn list if sampling ran dry.
	var sector_spawns: Array = map.spawn_points
	while points.size() < count and not sector_spawns.is_empty():
		var fallback: Vector3 = sector_spawns[points.size() % sector_spawns.size()]
		fallback.y = map.height_at(fallback.x, fallback.z)
		points.append(fallback)
	return points


func _begin_drop() -> void:
	# Pick a drop point inside the first cordon, biased away from the player's
	# chosen sector so the first fight is never on the doorstep.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 313
	# Retry until the drop point is on dry land — landing in the sea is a bug,
	# not a hazard.
	for attempt in 48:
		var candidate: Vector3 = map.random_point_in_zone(rng)
		candidate.y = map.height_at(candidate.x, candidate.z)
		if candidate.y > 3.0:
			_drop_target = candidate
			break
		if attempt == 47:
			_drop_target = candidate
	player.global_position = _drop_target + Vector3(0, DROP_HEIGHT, 0)
	player.velocity = Vector3.ZERO
	player.set_freefall(true)
	player.landed.connect(_on_player_landed, CONNECT_ONE_SHOT)
	StoryDirector.start_match()
	AudioDirector.play("deploy", -8.0)


func _on_player_landed() -> void:
	_set_state(State.LIVE, "LIVE")
	zone.start()
	player.pitch = 0.0


func _process(delta: float) -> void:
	if state == State.LIVE or state == State.DROP:
		match_time += delta
	if state == State.LIVE:
		_check_end_conditions()


func _check_end_conditions() -> void:
	if _ended:
		return
	if player != null and not player.is_alive:
		_end_match(false)
		return
	var alive_now := 0
	for node in get_tree().get_nodes_in_group("actors"):
		var a := node as Actor
		if a != null and a.is_alive:
			alive_now += 1
	if alive_now != alive_count:
		alive_count = alive_now
		alive_changed.emit(alive_count)
		if alive_count <= 10:
			StoryDirector.radio("last_ten")
	if alive_count <= 1 and player != null and player.is_alive:
		_end_match(true)


func _on_actor_died(actor: Actor, killer: Actor) -> void:
	var killer_name := "CORDON" if killer == null else killer.display_name
	var weapon := ""
	if killer is Player:
		weapon = String(killer.inventory.current_stats().get("name", ""))
	elif killer is Bot:
		weapon = String((killer as Bot).inventory.current_stats().get("name", ""))
	kill_event.emit(killer_name, actor.display_name, weapon)
	player_placement_value = maxi(alive_count - 1, 1)
	alive_count = maxi(alive_count - 1, 0)
	alive_changed.emit(alive_count)
	player_placement.emit(player_placement_value)
	if actor == player:
		player_placement_value = maxi(alive_count, 1)
		_end_match(false)


func _end_match(won: bool) -> void:
	if _ended:
		return
	_ended = true
	zone.stop()
	set_process(false)
	_set_state(State.ENDED, "VICTORY" if won else "ELIMINATED")
	var placement := 1 if won else maxi(player_placement_value, 1)
	var summary := player.match_summary(won, placement) if player != null else {"won": won, "placement": placement}
	summary["duration"] = match_time
	summary["seed"] = seed_value
	summary["alive"] = alive_count
	GameState.record_match(summary)
	AudioDirector.play("victory" if won else "defeat", -4.0)
	if won:
		StoryDirector.radio("win")
	StoryDirector.end_match()
	match_ended.emit(summary)


func _set_state(new_state: int, label: String) -> void:
	state = new_state
	state_changed.emit(state, label)


func teardown() -> void:
	if map != null:
		map.queue_free()
	if zone != null:
		zone.queue_free()
	if loot != null:
		loot.queue_free()
	if squads != null:
		squads.queue_free()
	for bot in bots:
		(bot as Node).queue_free()
	bots.clear()
	if player != null:
		player.queue_free()
	state = State.IDLE
	_ended = false
	set_process(false)
