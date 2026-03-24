class_name CollectibleManager
extends Node
## Manages the spawning and collection of yellow target letters.
## Tracks collection progress and updates the circle's perimeter dots.

## Emitted when a collectible is picked up, with the new total count
signal collectible_collected(total: int)

## Emitted when all collectibles for the round are collected
signal all_collected()

## Reference to the letter grid (set by GameManager)
var grid: LetterGrid = null

## Reference to the game circle (set by GameManager)
var game_circle: GameCircle = null

## Reference to the player controller (set by GameManager)
var player: PlayerController = null

## Current collectible position in the grid (-1,-1 means none active)
var active_collectible_pos: Vector2i = Vector2i(-1, -1)

## Number of collectibles gathered so far
var collected_count: int = 0

## Total collectibles needed to complete the round (matches circle dot count)
var target_count: int = GameTheme.CIRCLE_DOT_COUNT


## Sets up references and connects to player movement signal.
func initialize(p_grid: LetterGrid, p_circle: GameCircle, p_player: PlayerController) -> void:
	grid = p_grid
	game_circle = p_circle
	player = p_player
	player.moved_to.connect(_on_player_moved)


## The minimum number of key presses the player must make to reach the gold letter.
## 4 means the gold letter is always at least 4 moves away — never right next door.
## Increase to make the player travel further for each collectible; decrease for shorter trips.
const MIN_DISTANCE: int = 4

## Spawns a new collectible at a cell at least MIN_DISTANCE keystrokes from the player.
## Falls back to smaller distances if not enough far cells are available.
func spawn_collectible() -> void:
	if grid == null:
		return

	var all_positions: Array[Vector2i] = GridHelpers.all_positions()
	var player_pos: Vector2i = Vector2i(player.current_row, player.current_col)

	## BFS from the player to get move-distance to every reachable cell
	var distances: Dictionary = GridHelpers.bfs_distances(player.current_row, player.current_col)

	## Try MIN_DISTANCE first, then fall back to smaller distances if needed
	var candidates: Array[Vector2i] = []
	var required_dist: int = MIN_DISTANCE
	while candidates.is_empty() and required_dist >= 1:
		for pos in all_positions:
			if pos == player_pos:
				continue
			var d: int = distances.get(pos, 0)
			if d >= required_dist:
				candidates.append(pos)
		if candidates.is_empty():
			required_dist -= 1

	## Last resort: any cell other than the player's own
	if candidates.is_empty():
		for pos in all_positions:
			if pos != player_pos:
				candidates.append(pos)

	## Pick a random candidate
	if candidates.is_empty():
		return

	var chosen: Vector2i = candidates[randi() % candidates.size()]
	active_collectible_pos = chosen

	## Set the cell to collectible state
	var cell: LetterCell = grid.get_cell(chosen.x, chosen.y)
	if cell:
		cell.set_state(LetterCell.CellState.COLLECTIBLE)

	## Update the circle to show the next target dot
	if game_circle:
		game_circle.set_active_dot(collected_count)


## Called when the player moves to a new cell.
func _on_player_moved(row: int, col: int, _letter: String) -> void:
	if active_collectible_pos == Vector2i(row, col):
		_collect()


## Handles collecting the current collectible.
func _collect() -> void:
	collected_count += 1

	## Update circle dots
	if game_circle:
		game_circle.set_filled_dots(collected_count)

	## Clear the active collectible
	active_collectible_pos = Vector2i(-1, -1)

	collectible_collected.emit(collected_count)

	## Check if round is complete
	if collected_count >= target_count:
		all_collected.emit()
	else:
		## Spawn the next collectible
		spawn_collectible()


## Resets the collectible system for a new round.
func reset() -> void:
	collected_count = 0
	active_collectible_pos = Vector2i(-1, -1)
	if game_circle:
		game_circle.set_filled_dots(0)
		game_circle.set_active_dot(-1)
