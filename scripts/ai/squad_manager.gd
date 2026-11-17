class_name SquadManager
extends Node
## Squad blackboard + roster. Bots publish contacts here and read teammates'
## contacts, which is what produces pincer behaviour without any coordination
## code in the bots themselves.

const SQUAD_NAMES := [
	"SALT-6", "ROOK NINE", "GREY LANCE", "KESTREL REMNANT", "HOLLOWMEN",
	"BRINE WOLVES", "TALLOW", "SABLE FOUR", "MERIDIAN AUX", "CORMORANT",
	"IRON TIDE", "DUST OFF", "NIGHTJAR", "SALT DOGS", "LAST LIGHT",
]

var squads: Dictionary = {}        # squad_id -> Array[Bot]
var contacts: Dictionary = {}      # squad_id -> Actor
var squad_names: Dictionary = {}   # squad_id -> String
var player_squad := 0


func register(bot: Bot) -> void:
	if not squads.has(bot.squad_id):
		squads[bot.squad_id] = []
	squads[bot.squad_id].append(bot)
	if not squad_names.has(bot.squad_id):
		squad_names[bot.squad_id] = SQUAD_NAMES[int(bot.squad_id) % SQUAD_NAMES.size()]


func alert(squad_id: int, enemy: Actor) -> void:
	if squad_id < 0 or enemy == null:
		return
	contacts[squad_id] = enemy


func squad_target(squad_id: int) -> Actor:
	var t: Variant = contacts.get(squad_id)
	if t is Actor and (t as Actor).is_alive:
		return t
	return null


func alive_in_squad(squad_id: int) -> int:
	var count := 0
	for bot in squads.get(squad_id, []):
		if (bot as Bot).is_alive:
			count += 1
	return count


func squads_alive() -> int:
	var count := 0
	for id in squads.keys():
		if alive_in_squad(int(id)) > 0:
			count += 1
	return count


func name_of(squad_id: int) -> String:
	return String(squad_names.get(squad_id, "UNKNOWN"))


func total_alive() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("actors"):
		var a := node as Actor
		if a != null and a.is_alive:
			count += 1
	return count


func last_squad_standing() -> int:
	var winner := -1
	for id in squads.keys():
		if alive_in_squad(int(id)) > 0:
			if winner != -1:
				return -1
			winner = int(id)
	return winner
