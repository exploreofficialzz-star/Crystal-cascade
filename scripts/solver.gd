class_name Solver
extends RefCounted
## Beam search: finds a short solution for a board within a node and time budget.
## Used for the per-level move budget and for the auto-playing hint.

const MAX_DEPTH := 90


# Returns the moves as [[from, to], ...], or [] when none was found within the limits.
static func solve(tubes: Array, caps: Array, width: int, max_nodes: int, max_ms: int) -> Array:
	if Rules.is_cleared(tubes):
		return []
	var t0: int = Time.get_ticks_msec()
	var n: int = tubes.size()
	var parents: Array = [-1]
	var mv_from: Array = [0]
	var mv_to: Array = [0]
	var cur_states: Array = [tubes.duplicate(true)]
	var cur_ids: Array = [0]
	var visited: Dictionary = {}
	visited[_key(tubes)] = true
	var expanded: int = 0
	for depth in range(MAX_DEPTH):
		var buckets: Dictionary = {}
		for si in range(cur_states.size()):
			var st: Array = cur_states[si]
			var sizes: Array = []
			var tops: Array = []
			for q in range(n):
				var tq: Array = st[q]
				var sz: int = tq.size()
				sizes.append(sz)
				if sz > 0:
					tops.append(tq[sz - 1] & 15)
				else:
					tops.append(-1)
			for i in range(n):
				if sizes[i] == 0:
					continue
				var c: int = tops[i]
				var uniform: bool = Rules.top_run(st[i]) == sizes[i]
				for j in range(n):
					if j == i:
						continue
					if sizes[j] >= int(caps[j]):
						continue
					if sizes[j] > 0:
						if tops[j] != c:
							continue
					elif uniform:
						continue
					var nt: Array = st.duplicate(true)
					Rules.apply_move(nt, i, j)
					expanded += 1
					if Rules.is_cleared(nt):
						var path: Array = _path(parents, mv_from, mv_to, int(cur_ids[si]))
						path.append([i, j])
						return path
					var key: int = _key(nt)
					if visited.has(key):
						continue
					visited[key] = true
					var sc: int = _score(nt)
					var id: int = parents.size()
					parents.append(cur_ids[si])
					mv_from.append(i)
					mv_to.append(j)
					if not buckets.has(sc):
						buckets[sc] = []
					buckets[sc].append([nt, id])
			if expanded > max_nodes or Time.get_ticks_msec() - t0 > max_ms:
				return []
		var keys: Array = buckets.keys()
		keys.sort()
		cur_states = []
		cur_ids = []
		for sc2 in keys:
			for entry in buckets[sc2]:
				if cur_states.size() >= width:
					break
				cur_states.append(entry[0])
				cur_ids.append(entry[1])
			if cur_states.size() >= width:
				break
		if cur_states.is_empty():
			return []
	return []


# Best single move when no full solution was found: prefers clears, then the best-looking board.
static func best_effort(tubes: Array, caps: Array) -> Array:
	var best: Array = []
	var best_sc: int = 1000000
	for mv in Rules.legal_moves(tubes, caps):
		var a: int = mv[0]
		var b: int = mv[1]
		var nt: Array = tubes.duplicate(true)
		var ev: Array = Rules.apply_move(nt, a, b)
		var sc: int = _score(nt) - ev.size() * 40
		if tubes[b].is_empty() and Rules.top_run(tubes[a]) == tubes[a].size():
			sc += 25
		if sc < best_sc:
			best_sc = sc
			best = [a, b]
	return best


# Colours only (flags stripped), deep copy.
static func colors_only(tubes: Array) -> Array:
	var out: Array = []
	for t in tubes:
		var row: Array = []
		for v in t:
			row.append(v & 15)
		out.append(row)
	return out


static func key_of(tubes: Array) -> int:
	return _key(tubes)


# Order-sensitive fingerprint: identifies a board by tube position (used to follow a plan).
static func key_exact(tubes: Array) -> int:
	var total: int = 17
	for t in tubes:
		var h: int = 7
		for v in t:
			h = (h * 31 + (v & 15) + 1) % 1000003
		h = (h * 2654435 + t.size() * 977) % 1000000007
		total = (total * 1000003 + h) % 1000000007
	return total


static func _path(parents: Array, mv_from: Array, mv_to: Array, id: int) -> Array:
	var rev: Array = []
	var cur: int = id
	while cur > 0:
		rev.append([mv_from[cur], mv_to[cur]])
		cur = int(parents[cur])
	rev.reverse()
	return rev


# Order-independent state fingerprint (tubes may be permuted freely).
static func _key(tubes: Array) -> int:
	var total: int = 0
	for t in tubes:
		var h: int = 7
		for v in t:
			h = (h * 31 + (v & 15) + 1) % 1000003
		h = (h * 2654435 + t.size() * 977) % 1000000007
		total = (total + (h * 1000003 + 12345) % 998244353 * ((h % 9973) + 1)) % 1000000007
	return total


# Lower is better: fewer crystals, fewer colour changes, fewer buried crystals, more ready pairs.
static func _score(tubes: Array) -> int:
	var rem: int = 0
	var changes: int = 0
	var buried: int = 0
	var pairs: int = 0
	for t in tubes:
		var n: int = t.size()
		rem += n
		if n == 0:
			continue
		var bottom: int = t[0] & 15
		for j in range(1, n):
			var c: int = t[j] & 15
			if c != (t[j - 1] & 15):
				changes += 1
			if c != bottom:
				buried += 1
		if n >= 2 and (t[n - 1] & 15) == (t[n - 2] & 15):
			pairs += 1
	return rem * 6 + changes * 3 + buried - pairs * 2 + 100
