class_name Rules
extends RefCounted
## Pure board rules shared by the game, the level generator and the solver.
##
## A crystal is an int: bits 0-3 = colour index, 16 = hidden (mystery), 32 = gold.
## A board is an Array of tubes (bottom -> top); a tube is an Array of crystals.

const COLOR_MASK := 15
const F_HIDDEN := 16
const F_GOLD := 32


static func col(v: int) -> int:
	return v & 15


# Length of the same-colour run at the top of a tube.
static func top_run(tube: Array) -> int:
	var n: int = tube.size()
	if n == 0:
		return 0
	var c: int = tube[n - 1] & 15
	var r: int = 1
	var i: int = n - 2
	while i >= 0 and (tube[i] & 15) == c:
		r += 1
		i -= 1
	return r


static func can_move(tubes: Array, caps: Array, from_i: int, to_i: int) -> bool:
	if from_i == to_i:
		return false
	var src: Array = tubes[from_i]
	if src.is_empty():
		return false
	var dst: Array = tubes[to_i]
	if dst.size() >= int(caps[to_i]):
		return false
	if dst.is_empty():
		return true
	return (dst[dst.size() - 1] & 15) == (src[src.size() - 1] & 15)


# Moves the top crystal of from_i onto to_i and resolves every match this causes.
# A cleared triple can expose another one underneath (a cascade), and lifting a
# crystal can expose a buried triple, so both tubes are resolved.
# Returns the clears in order, each as [tube, colour, gold_count].
static func apply_move(tubes: Array, from_i: int, to_i: int) -> Array:
	var events: Array = []
	var v: int = tubes[from_i].pop_back()
	tubes[to_i].append(v)
	_resolve(tubes, to_i, events)
	_resolve(tubes, from_i, events)
	return events


# Resolves matches on one tube without a move (used when a crystal is conjured onto it).
static func resolve_tube(tubes: Array, idx: int) -> Array:
	var events: Array = []
	_resolve(tubes, idx, events)
	return events


static func _resolve(tubes: Array, idx: int, events: Array) -> void:
	var t: Array = tubes[idx]
	while t.size() >= 3 and top_run(t) >= 3:
		var n: int = t.size()
		var c: int = t[n - 1] & 15
		var golds: int = 0
		for q in range(3):
			if (t[n - 1 - q] & 32) != 0:
				golds += 1
		t.pop_back()
		t.pop_back()
		t.pop_back()
		events.append([idx, c, golds])


# True when no colour has three or more crystals left, i.e. nothing can match any more.
static func is_cleared(tubes: Array) -> bool:
	var counts: Array = [0, 0, 0, 0, 0, 0, 0, 0]
	for t in tubes:
		for v in t:
			var c: int = v & 15
			counts[c] += 1
			if counts[c] >= 3:
				return false
	return true


static func any_move(tubes: Array, caps: Array) -> bool:
	var n: int = tubes.size()
	for i in range(n):
		if tubes[i].is_empty():
			continue
		for j in range(n):
			if can_move(tubes, caps, i, j):
				return true
	return false


# Every legal move as [from, to].
static func legal_moves(tubes: Array, caps: Array) -> Array:
	var out: Array = []
	var n: int = tubes.size()
	for i in range(n):
		if tubes[i].is_empty():
			continue
		for j in range(n):
			if can_move(tubes, caps, i, j):
				out.append([i, j])
	return out


static func count_crystals(tubes: Array) -> int:
	var n: int = 0
	for t in tubes:
		n += t.size()
	return n


# Number of crystals of colour c on the board.
static func count_color(tubes: Array, c: int) -> int:
	var n: int = 0
	for t in tubes:
		for v in t:
			if (v & 15) == c:
				n += 1
	return n
