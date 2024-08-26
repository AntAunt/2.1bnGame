extends TileMapLayer

class_name MinesGrid

const CELLS = {
	"DEFAULT": Vector2i(0, 0),
	"CLEAR": Vector2i(1, 0),
	"ONE": Vector2i(2, 0),
	"TWO": Vector2i(3, 0),
	"THREE": Vector2i(4, 0),
	"FOUR": Vector2i(5, 0),
	"FIVE": Vector2i(6, 0),
	"SIX": Vector2i(7, 0),
	"SEVEN": Vector2i(0, 1),
	"EIGHT": Vector2i(1, 1),
	"NINE": Vector2i(2, 1),
	"ERROR": Vector2i(3, 1),
	"MINE": Vector2i(4, 1),
	"FLAG": Vector2i(5, 1),
	"HEALTH": Vector2i(6, 1),
	"MANA": Vector2i(7, 1),
	"TREASURE": Vector2i(0, 2),
	"CLICKED": Vector2i(1, 2),
	"WALL": Vector2i(2, 2)
}

# Default values are very highly specific, will need some research to fix this

@export var columns = 35
@export var rows = 14
@export var num_of_mines = 30
@export var x_offset = 17
@export var y_offset = 7

const TILE_SET_ID = 0
const DEFAULT_LAYER = 0

var cells = []
var cells_with_mines = []
var cells_with_flags = []
var cells_with_health = []
var cells_with_mana = []
var cells_with_treasure = []
var flags_placed = []
var cells_checked_recursively = []
var first_click = true

# Temp values from copy

var is_game_finished = false
var revealed_cells = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	clear()
	
	for i in columns:
		for j in rows:
			var cell_coord = Vector2i((i - columns / 2) + x_offset, (j - rows / 2) + y_offset )
			cells.append(cell_coord)
			set_tile_cell(cell_coord, CELLS.DEFAULT)

func _input(event: InputEvent):

	if is_game_finished:
		return
	
	var clicked_cell_coord = local_to_map(get_local_mouse_position())
	
	if !cells.has(clicked_cell_coord):
		return
	
	if event is InputEventMouseButton && event.pressed:
		if event.button_index == 1:
			on_cell_clicked(clicked_cell_coord)
		elif event.button_index == 2:
			place_flag(clicked_cell_coord)
		elif event.button_index == 3:
			quick_reveal(clicked_cell_coord)
	elif event is InputEventKey && event.pressed && event.key_label == KEY_SPACE:
		quick_reveal(clicked_cell_coord)

func place_mines(cell_coord: Vector2i):
	
	var safe_cells = []
	var surrounding_cells = get_surrounding_cells_to_check(cell_coord)
	var starting_cell_should_border_mines = rows * columns - num_of_mines < 8
	var instant_loss = rows * columns <= num_of_mines
	
	if !instant_loss:
		for i in columns:
			for j in rows:
				var target_cell = Vector2i(i - columns / 2 + x_offset, j - rows / 2 + y_offset)
				if target_cell == cell_coord:
					safe_cells.append(target_cell)
				if !starting_cell_should_border_mines && surrounding_cells.has(target_cell):
					safe_cells.append(target_cell)
	
	for i in num_of_mines:
		var cell_coordinates = Vector2i(randi_range(- columns/2 + x_offset, columns/2 - 1 + x_offset), randi_range(-rows/2 + y_offset, rows /2 - 1 + y_offset))
		
		while cells_with_mines.has(cell_coordinates) || safe_cells.has(cell_coordinates):
			cell_coordinates = Vector2i(randi_range(- columns / 2 + x_offset, columns/2 -1 + x_offset), randi_range(-rows/2 + y_offset, rows /2 -1 + y_offset))
		
		cells_with_mines.append(cell_coordinates)
		
	
	for cell in cells_with_mines:
		erase_cell(cell)
		set_cell(cell, TILE_SET_ID, CELLS.DEFAULT, 1)

func set_tile_cell(cell_coord, cell_type):
	set_cell(cell_coord, TILE_SET_ID, cell_type)
	
func on_cell_clicked(cell_coord: Vector2i):
	if !cells.has(cell_coord):
		return
	
	if first_click:
		first_click = false
		# game_start.emit()
		place_mines(cell_coord)

	if !is_game_finished && cells_with_mines.any(func (cell): return cell.x == cell_coord.x && cell.y == cell_coord.y):
		lose(cell_coord)
		return
	
	cells_checked_recursively.append(cell_coord)
	handle_cells(cell_coord, true)
	
	if cells_with_flags.has(cell_coord):
		return

func handle_cells(cell_coord: Vector2i, should_stop_after_mine: bool = true):
	if cells_with_flags.has(cell_coord):
		return
		
	var tile_data = get_cell_tile_data(cell_coord)
	
	if tile_data == null:
		return
		
	var cell_has_mine = cells_with_mines.has(cell_coord)
	
	if cell_has_mine && should_stop_after_mine:
		return
	
	var mine_count = get_surrounding_cells_mine_count(cell_coord)
	
	if mine_count == 0:
		set_tile_cell(cell_coord, CELLS.CLEAR)
		revealed_cells += 1
		var surrounding_cells = get_surrounding_cells_to_check(cell_coord)
		for cell in surrounding_cells:
			handle_surrounding_cell(cell)
	else:
		set_tile_cell(cell_coord, get_surrounding_mine_number(mine_count))
		revealed_cells += 1
	
	if (revealed_cells == columns * rows - num_of_mines):
		win()

func handle_surrounding_cell(cell_coord: Vector2i):
	if cells_checked_recursively.has(cell_coord):
		return
	
	cells_checked_recursively.append(cell_coord)
	handle_cells(cell_coord)		
	
func get_surrounding_cells_mine_count(cell_coord: Vector2i):
	var mine_count = 0
	var surrounding_cells = get_surrounding_cells_to_check(cell_coord)
	for cell in surrounding_cells:
		if cells_with_mines.has(cell):
			mine_count += 1
	
	return mine_count
	
func get_surrounding_cells_flag_count(cell_coord: Vector2i):
	var flag_count = 0
	var surrounding_cells = get_surrounding_cells_to_check(cell_coord)
	for cell in surrounding_cells:
		if cells_with_flags.has(cell):
			flag_count += 1
	
	return flag_count

func lose(cell_coord: Vector2i):
	# game_lost.emit()
	is_game_finished = true
	
	for cell in cells_with_mines:
		set_tile_cell(cell, "MINE")
	
	set_tile_cell(cell_coord, "MINE_RED")
	
func place_flag(cell_coord: Vector2i):
	
	if first_click:
		# game_start.emit()
		first_click = false
	
	var atlast_coordinates = get_cell_atlas_coords(cell_coord)
	var is_empty_cell = atlast_coordinates == Vector2i(2,2)
	var is_flag_cell = atlast_coordinates == Vector2i(0, 2)
	
	if !is_empty_cell and !is_flag_cell:
		return
	
	if is_flag_cell:
		set_tile_cell(cell_coord, "DEFAULT")
		cells_with_flags.erase(cell_coord)
		flags_placed -= 1
	elif is_empty_cell:
		
		if flags_placed == num_of_mines:
			return
		
		flags_placed +=1 
		set_tile_cell(cell_coord, "FLAG")
		cells_with_flags.append(cell_coord)
	
	# flag_change.emit(flags_placed)

func quick_reveal(cell_coord: Vector2i):
	
	var atlast_coordinates = get_cell_atlas_coords(cell_coord)
	var is_empty_cell = atlast_coordinates == Vector2i(2,2)
	var target_cell
	
	if is_empty_cell || cells_with_flags.has(cell_coord):
		place_flag(cell_coord)
		return
	if !(get_surrounding_cells_flag_count(cell_coord) == get_surrounding_cells_mine_count(cell_coord)):
		return
		
	for y in 3:
		for x in 3:
			if x == 1 and y == 1:
				continue
			target_cell = cell_coord + Vector2i(x - 1, y - 1)
			if cells_with_flags.has(target_cell):
				continue
			if !(get_cell_atlas_coords(target_cell) == Vector2i(2,2)):
				continue
			on_cell_clicked(target_cell)

func win():
	for i in columns:
		for j in rows:
			var cell_coord = Vector2i(i - columns / 2 + x_offset, j - rows / 2 + y_offset)
			if (cells_with_flags.has(cell_coord)):
				continue
			if (cells_with_mines.has(cell_coord)):
				set_tile_cell(cell_coord, "FLAG")
				flags_placed +=1
				# flag_change.emit(flags_placed)
			else:
				on_cell_clicked(cell_coord)
	is_game_finished = true
	# game_won.emit()
	

func get_surrounding_cells_to_check(current_cell:Vector2i):
	var target_cell
	var surrounding_cells = []
	
	for y in 3:
		for x in 3:
			if x == 1 and y == 1:
				continue
			target_cell = current_cell + Vector2i(x - 1, y - 1)
			surrounding_cells.append(target_cell)
	
	return surrounding_cells
	
func get_surrounding_mine_number(mines: int):
	match mines:
		0:
			return CELLS.CLEAR
		1:
			return CELLS.ONE
		2:
			return CELLS.TWO
		3:
			return CELLS.THREE
		4:
			return CELLS.FOUR
		5:
			return CELLS.FIVE
		6:
			return CELLS.SIX
		7:
			return CELLS.SEVEN
		8:
			return CELLS.EIGHT
		
