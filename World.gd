extends Node2D

onready var player = $Player
onready var animation_tree = $Player/AnimationTree
onready var animation_state = animation_tree.get("parameters/playback")
onready var col_map = $CollisionMap
onready var path_map = $PathMap

const ACCEPTABLE_DISTANCE = 1
const SCREEN_WIDTH = 480
const SCREEN_HEIGHT = 320
const SPEED = 50
const BIT_SIZE = 32
const NUM_COLS = SCREEN_WIDTH / BIT_SIZE
const NUM_ROWS = SCREEN_HEIGHT / BIT_SIZE 

var grid = []
var opened_set = []
var closed_set = []
var end = null
var path = []
var has_path = false

# Called when the node enters the scene tree for the first time.
func _ready():
	setup_grid()
	load_neighbors()
	set_end_position()
	a_star()
	build_path()
	
func set_end_position():
	for y in range(NUM_ROWS):
		for x in range(NUM_COLS):
			if col_map.get_cell(x, y) == 1:
				end = grid[y][x]
				return
	end = grid[0][0]
	return
	
func build_path():
	var curr = end
	while curr:
		path.push_front(curr)
		path_map.set_cell(curr.x, curr.y, 0)
		curr = curr.previous
		
	path_map.set_cell(end.x, end.y, 0)
	path_map.update_bitmask_region(Vector2(0.0, 0.0), Vector2(SCREEN_WIDTH, SCREEN_HEIGHT))
	
func setup_grid():
	for y in range(NUM_ROWS):
		grid.append([])
		for x in range(NUM_COLS):
			var pos = Vector2.ZERO
			pos.x = x * BIT_SIZE
			pos.y = y * BIT_SIZE
			
			var wall = false
			if col_map.get_cell(x, y) == 0:
				wall = true
			
			var obj = {
				'x': x,
				'y': y,
				'f': 0,
				'g': 0,
				'h': 0,
				'position': pos,
				'neighbors': [],
				'visited': false,
				'wall': wall,
				'previous': null
			}
			
			grid[y].append(obj)
	
func load_neighbors():
	for y in range(NUM_ROWS):
		for x in range(NUM_COLS):
			grid[y][x].neighbors = get_neighbors(grid[y][x])
		
func get_neighbors(cell):
	var neighbors = []
	
	if cell.y < NUM_ROWS - 1:
		neighbors.push_back(grid[cell.y + 1][cell.x])
	
	if cell.y > 0:
		neighbors.push_back(grid[cell.y - 1][cell.x])	
		
	if cell.x < NUM_COLS - 1:
		neighbors.push_back(grid[cell.y][cell.x + 1])
		
	if cell.x > 0:
		neighbors.push_back(grid[cell.y][cell.x - 1])
		
	return neighbors
	
func set_includes(set, cell):
	for i in range(set.size()):
		if set[i].x == cell.x && set[i].y == cell.y:
			return true
	
	return false
	
func heuristic(a, b):
	return abs(a.x - b.x) + abs(a.y - b.y)
	
func remove_cell(set, item):
	var index_to_remove = null
	
	for i in range(set.size()):
		
		if set[i].x == item.x && set[i].y == item.y:
			index_to_remove = i
			break
	
	if index_to_remove != null:		
		set.remove(index_to_remove)
		
	return set
	
func a_star():
	player.position = grid[0][0].position
	opened_set.push_back(grid[0][0])
	
	while opened_set.size() > 0:
		var winner = 0
		for i in range(opened_set.size()):
			if opened_set[i].f < opened_set[winner].f:
				winner = i
		
		var current = opened_set[winner]
		opened_set = remove_cell(opened_set, current)
		closed_set.push_back(current)
		
		for j in range(current.neighbors.size()):
			var neighbor = current.neighbors[j]
			
			if neighbor.wall == false && !set_includes(closed_set, neighbor):
				var temp_g = current.g + 1
				var new_path = false
				
				if set_includes(opened_set, neighbor):
					if temp_g < neighbor.g:
						neighbor.g = temp_g
						new_path = true
				else:
					neighbor.g = temp_g
					new_path = true
					opened_set.push_back(neighbor)
					
				if new_path:
					neighbor.h = heuristic(neighbor, end)
					neighbor.f = neighbor.g + neighbor.h
					neighbor.previous = current
					
					if neighbor.x == end.x && neighbor.y == end.y:
						has_path = true
						print("path found")
						return
	
	print("no path found")
	return
	
func _physics_process(delta):
	if has_path && path.size() > 0:
		var target = path[0]
		var origin = player.get_node("Position2D").get_global_position()
		
		var vector = Vector2.ZERO
		var distance = get_distance(origin, target.position);
		
		if distance > ACCEPTABLE_DISTANCE:
			vector = (target.position - origin).normalized()
			player.move_and_collide(vector * SPEED * delta)	
			animation_state.travel("Walk")
			animation_tree.set("parameters/Idle/blend_position", vector)
			animation_tree.set("parameters/Walk/blend_position", vector)
		else:
			animation_state.travel("Idle")
			path.remove(0)
			player.move_and_collide(Vector2.ZERO)
	else:
		animation_state.travel("Idle")
		player.move_and_collide(Vector2.ZERO)
	

func get_distance(pos1, pos2):
	return sqrt(pow((pos2.x - pos1.x), 2) + pow((pos2.y - pos1.y), 2))
