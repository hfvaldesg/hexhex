extends Spatial

const MapUtils = preload("res://src/map/MapUtils.gd")

signal click
signal click_outside
signal show_neighbours
signal show_line
const HEX_SCALE = 5

var selected_hex
var all_hex = []
var local_positions = {}
var obstacle_positions = []
var map_limits = {
	"max_x": 0,
	"min_x": 0,
	"max_z": 0,
	"min_z": 0,
}

func _init(levels):
	create(levels)
	add_random_knights(10)

func get_selected_hex():
	return selected_hex

func set_selected_hex(position):
	selected_hex = position

func get_map_limits():
	return map_limits

func get_local_positions():
	return local_positions
	
func create(levels):
	var hex
	var global_position = Vector3(0, 0, 0)
	var local_position = Vector3(0, 0, 0)
	
	# Initialize the center (and first) hexagon tile
	hex = load("res://src/map/Hexagon.gd").new(global_position, local_position, HEX_SCALE)
	add_child(hex)
	connect("click", hex, "_on_click")
	connect("click_outside", hex, "_on_click_outside")
	connect("show_neighbours", hex, "_on_show_neighbours")
	connect("show_line", hex, "_on_show_line")	
	
	all_hex.push_back(global_position)
	local_positions[global_position] = local_position
	var new_hex = []
	var old_hex = []
	for n in range(0, levels):
		if n == 0:
			old_hex.push_back(global_position)
		for base_hex in old_hex:
			for i in range(1, 7):
				var local_vector = local_positions.get(base_hex)
				if i == 1:
					global_position = base_hex+ Vector3(1, 0, 0) * HEX_SCALE
					local_position =  local_vector + Vector3(1, -1, 0)
				elif i == 2:
					global_position = base_hex + Vector3(0.5, 0, 0.75) * HEX_SCALE
					local_position =  local_vector + + Vector3(0, -1, 1)
				elif i == 3:
					global_position = base_hex +Vector3(-0.5, 0, 0.75) * HEX_SCALE
					local_position =  local_vector + Vector3(-1, 0, 1)
				elif i == 4:
					global_position = base_hex + Vector3(-1, 0, 0) * HEX_SCALE
					local_position =  local_vector + Vector3(-1, 1, 0)
				elif i == 5:
					global_position = base_hex + Vector3(-0.5, 0, -0.75) * HEX_SCALE
					local_position =  local_vector + Vector3(0, 1, -1)
				elif i == 6:
					global_position = base_hex + Vector3(0.5, 0, -0.75) * HEX_SCALE
					local_position =  local_vector + Vector3(1, 0, -1)
					
				if !local_positions.has(global_position):
					hex = load("res://src/map/Hexagon.gd").new(global_position, local_position, HEX_SCALE)
					add_child(hex)
					connect("click", hex, "_on_click")
					connect("click_outside", hex, "_on_click_outside")
					connect("show_neighbours", hex, "_on_show_neighbours")
					connect("show_line", hex, "_on_show_line")
					hex.translate(global_position)
					new_hex.push_back(global_position)
					local_positions[global_position] = local_position
					
					# Determine min, max values
					if global_position.x > map_limits["max_x"]:
						map_limits["max_x"] = global_position.x
					if global_position.x < map_limits["min_x"]:
						map_limits["min_x"]= global_position.x
					if global_position.z > map_limits["max_z"]:
						map_limits["max_z"] = global_position.z
					if global_position.z < map_limits["min_z"]:
						map_limits["min_z"] = global_position.z
						
		all_hex += new_hex
		old_hex = new_hex
		new_hex = []

func get_neighbours(local_vector):
	return MapUtils.get_neighbours(local_vector, local_positions, obstacle_positions)

func hex_linedraw(a, b):
	var N = MapUtils.get_distance(a, b)
	var results = []
	for i in range(0, N+1):
		results.push_back(MapUtils.hex_round(MapUtils.hex_lerp(a, b, 1.0/N * i)))
	return results

func priorityComparisson(a, b):
	# [Vector3, priority]
	return a[1] > b[1]

func pathfinding(start, goal):
	# Using A-Star Algorithm from redblobgames.com
	var frontier = []
	frontier.push_back([start, 0])
	var came_from = {}
	var cost_so_far = {}
	came_from[start] = null
	cost_so_far[start] = 0
	var count = 0
	while !frontier.empty():
		var current = frontier.back()[0]
		frontier.pop_back()
		if current == goal:
			break

		for next in MapUtils.get_neighbours(current, local_positions, obstacle_positions):
			var new_cost = cost_so_far[current] + 1 # Change to graph.cost(current, next)
			if !cost_so_far.has(next) || new_cost < cost_so_far[next]:
				cost_so_far[next] = new_cost
				var priority = new_cost + MapUtils.get_distance(goal, next)
				frontier.push_front([next, priority])
				frontier.sort_custom(self, "priorityComparisson")
				came_from[next] = current
	var path = []
	find_path(goal, came_from, path)
	return path
	
func find_path(hex, came_from, path):
	if came_from.has(hex):
		path.push_back(hex)
		if came_from[hex] != null:
			var new_hex = came_from[hex]
			find_path(new_hex, came_from, path)
		else:
			return path

func add_random_knights(count):
	while count > 0:
		var knight = load("res://entities/knight/knight.gd").new()
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var random_index = rng.randi_range(0, all_hex.size() - 1)
		var kn_global_position = all_hex[random_index]
		var kn_local_position = local_positions[kn_global_position]
		if !obstacle_positions.has(kn_local_position):
			add_child(knight)
			knight.translate(kn_global_position)
			obstacle_positions.push_back(kn_local_position)
			count -= 1