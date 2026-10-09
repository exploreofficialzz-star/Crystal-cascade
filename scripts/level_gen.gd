class_name LevelGen
extends RefCounted
## Endless, deterministic level generator: level N always produces the same board.
##
## Boards are built by playing the game BACKWARDS from the solved state, so every
## level is solvable by construction. The forward solution is replayed with Rules
## before a board is accepted, and a beam search measures the real par.

const THEMES := 9
const THEME_NAMES := [
	"Crystal Grotto", "Amethyst Hall", "Frost Cavern", "Emerald Glade", "Ember Vault",
	"Rose Quartz", "Midnight Aurora", "Sunlit Atrium", "Royal Vault",
]
const CAP_CYCLE := [6, 6, 7, 5, 6, 8, 6, 7]
const SLACK_EARLY := [2.0, 1.9, 1.8, 1.7, 1.7, 1.65, 1.65, 1.6, 1.6, 1.55, 1.55, 1.5]
# colours, empty tubes, capacity, crystals per colour, gold, cascades, mystery
const ONBOARDING := [
	[2, 1, 6, 6, 0, 0, 0],
	[3, 1, 6, 6, 0, 0, 0],
	[3, 2, 6, 6, 2, 0, 0],
	[4, 2, 6, 6, 0, 0, 0],
	[3, 1, 5, 6, 2, 0, 0],
	[3, 2, 6, 6, 0, 1, 0],
	[4, 2, 6, 6, 2, 1, 0],
	[5, 2, 6, 6, 0, 0, 0],
	[4, 2, 6, 6, 0, 0, 3],
	[5, 1, 6, 6, 3, 2, 0],
	[4, 2, 7, 6, 0, 1, 2],
	[5, 2, 6, 6, 3, 0, 3],
]
const FALLBACK_BOARD := [[0, 1, 0], [1, 0, 1], []]
const FALLBACK_SOLUTION := [[0, 2], [1, 0], [1, 2], [1, 0], [0, 2]]


# ── level parameters ──────────────────────────────────────────────────────────

static func spec(n: int) -> Dictionary:
	var lvl: int = maxi(1, n)
	var pos: int = (lvl - 1) % 10
	var boss: bool = lvl >= 10 and lvl % 10 == 0
	var k: int = 2
	var e: int = 1
	var cap: int = 6
	var g: int = 6
	var gold: int = 0
	var casc: int = 0
	var myst: int = 0
	var slack: float = 1.5
	if lvl <= 12:
		var row: Array = ONBOARDING[lvl - 1]
		k = row[0]
		e = row[1]
		cap = row[2]
		g = row[3]
		gold = row[4]
		casc = row[5]
		myst = row[6]
		slack = SLACK_EARLY[lvl - 1]
	else:
		var d: float = clampf(float(lvl - 12) / 88.0, 0.0, 1.0)
		k = 4 + roundi(d * 3.0)
		if boss:
			k += 1
		elif pos <= 1:
			k -= 1
		k = clampi(k, 3, 7)
		if boss:
			e = 1
		elif pos <= 1 or d < 0.3:
			e = 2
		elif pos >= 4 or d > 0.65:
			e = 1
		else:
			e = 2
		cap = CAP_CYCLE[floori(float(lvl) / 3.0) % 8]
		if pos == 0 and floori(float(lvl) / 10.0) % 2 == 1:
			g = 3
			k = mini(7, k + 2)
			cap = clampi(cap, 4, 6)
		else:
			cap = maxi(cap, 5)
		var total: int = k * g
		var myst_n: int = floori(float(total) * (0.12 + 0.22 * d))
		var pat: int = lvl % 6
		if boss:
			gold = 3 + floori(d * 3.0)
			casc = 2
			if lvl >= 40:
				myst = floori(float(total) * 0.1)
		elif pat == 1:
			gold = 2 + roundi(d * 3.0)
		elif pat == 2:
			casc = 1 + roundi(d * 2.0)
		elif pat == 4:
			myst = myst_n
		elif pat == 5:
			gold = 2 + roundi(d * 2.0)
			casc = 1
		elif pat == 0:
			gold = 2 + roundi(d * 2.0)
			myst = myst_n
		slack = 1.5 - 0.2 * d
		if boss:
			slack += 0.05
		elif pos <= 1:
			slack += 0.05
		if myst > 0:
			slack += 0.1
	if casc > 0 and cap < 6:
		cap = 6
	var filler: int = ceili(float(k * g) / float(cap))
	while filler + e > 10 and cap < 8:
		cap += 1
		filler = ceili(float(k * g) / float(cap))
	if filler + e > 10:
		e = 1
	var theme: int = (lvl - 1) % 8
	if boss:
		theme = 8
	var twists: Array = []
	if boss:
		twists.append("boss")
	if gold > 0:
		twists.append("gold")
	if casc > 0:
		twists.append("cascade")
	if myst > 0:
		twists.append("mystery")
	return {
		"id": lvl, "k": k, "g": g, "capacity": cap, "empties": e, "filler": filler,
		"tubes": filler + e, "gold": gold, "cascade": casc, "mystery": myst, "boss": boss,
		"theme": theme, "name": THEME_NAMES[theme], "twists": twists, "slack": slack,
		"mix": 2 * k + 4,
	}


# ── building a level ──────────────────────────────────────────────────────────

# Full level: board, per-tube capacities, palette, verified solution, par and move budget.
static func build(n: int) -> Dictionary:
	var sp: Dictionary = spec(n)
	var base: int = int(sp["id"]) * 7919 + 1013
	for attempt in range(60):
		var data: Dictionary = _attempt(sp, base + attempt * 104729, attempt >= 30)
		if not data.is_empty():
			return _finish(sp, data)
	return _fallback(sp)


static func _attempt(sp: Dictionary, seed_value: int, plain: bool) -> Dictionary:
	var rng: Array = [((seed_value % 2147483629) * 69069 + 12345) & 0x7fffffff]
	var k: int = sp["k"]
	var g: int = sp["g"]
	var cap: int = sp["capacity"]
	var tn: int = sp["tubes"]
	var fcount: int = sp["filler"]
	var caps: Array = []
	var tubes: Array = []
	for q in range(tn):
		caps.append(cap)
		tubes.append([])
	var per: int = floori(float(g) / 3.0)
	var need: Array = []
	for q in range(k):
		need.append(per)
	var total: int = k * per
	var placed: int = 0
	var casc_left: int = 0
	if not plain:
		casc_left = int(sp["cascade"])
	var casc_total: int = casc_left
	var extra: int = sp["mix"]
	var moves: Array = []
	var guard: int = 0
	while placed < total or extra > 0:
		guard += 1
		if guard > 3000:
			return {}
		var added: int = 0
		if placed < total and (extra <= 0 or _rnd(rng, 100) < 50):
			var want_casc: bool = casc_left > 0 and (placed < 2 or _rnd(rng, 100) < 55)
			if want_casc:
				added = _op_add(tubes, caps, fcount, need, k, rng, moves, true)
				if added > 0:
					casc_left -= 1
			if added == 0:
				added = _op_add(tubes, caps, fcount, need, k, rng, moves, false)
			placed += added
		if added == 0:
			if _op_move(tubes, caps, fcount, rng, moves):
				extra -= 1
			elif placed < total:
				return {}
			else:
				break
	# settle: empty the workspace tubes into the filler tubes
	for w in range(fcount, tn):
		while not tubes[w].is_empty():
			var c: int = tubes[w][tubes[w].size() - 1]
			var dests: Array = []
			for i in range(fcount):
				if _push_ok(tubes, caps, fcount, i, c):
					dests.append(i)
			if dests.is_empty():
				return {}
			var i2: int = dests[_rnd(rng, dests.size())]
			tubes[w].pop_back()
			tubes[i2].append(c)
			moves.append([i2, w])
	if casc_left > 0:
		return {}
	moves.reverse()
	# sanity: nothing may start matched, and the forward solution must clear the board
	for t in tubes:
		if Rules.top_run(t) >= 3:
			return {}
	if not _verify(tubes, caps, moves):
		return {}
	_apply_flags(tubes, int(sp["gold"]), int(sp["mystery"]), rng)
	return {"board": tubes, "caps": caps, "solution": moves, "cascades": casc_total - casc_left, "rng": rng}


static func _finish(sp: Dictionary, data: Dictionary) -> Dictionary:
	var out: Dictionary = sp.duplicate()
	var rng: Array = data["rng"]
	var all7: Array = [0, 1, 2, 3, 4, 5, 6]
	_shuffle(rng, all7)
	var palette: Array = []
	for q in range(int(sp["k"])):
		palette.append(all7[q])
	var board: Array = data["board"]
	var caps: Array = data["caps"]
	var sol: Array = data["solution"]
	var found: Array = Solver.solve(board, caps, 8, 2500, 200)
	var par: int = sol.size()
	if not found.is_empty() and found.size() < par:
		par = found.size()
		sol = found
	out["board"] = board
	out["caps"] = caps
	out["palette"] = palette
	out["solution"] = sol
	out["cascades"] = data["cascades"]
	_set_budget(out, par)
	return out


# par -> move budget and star thresholds ("moves used").
static func _set_budget(out: Dictionary, par: int) -> void:
	var budget: int = maxi(ceili(float(par) * float(out["slack"])), par + 3)
	var t3: int = par + maxi(1, floori(float(par) * 0.2))
	var t2: int = par + floori(float(budget - par) * 0.6)
	t2 = mini(maxi(t2, t3), budget)
	out["par"] = par
	out["budget"] = budget
	out["star3"] = t3
	out["star2"] = t2


static func _fallback(sp: Dictionary) -> Dictionary:
	var out: Dictionary = sp.duplicate()
	out["board"] = FALLBACK_BOARD.duplicate(true)
	out["caps"] = [6, 6, 6]
	out["palette"] = [0, 1]
	out["solution"] = FALLBACK_SOLUTION.duplicate(true)
	out["k"] = 2
	out["g"] = 3
	out["capacity"] = 6
	out["tubes"] = 3
	out["empties"] = 1
	out["gold"] = 0
	out["cascade"] = 0
	out["mystery"] = 0
	out["cascades"] = 0
	out["twists"] = []
	out["slack"] = 2.0
	_set_budget(out, 5)
	return out


# Replays a forward solution with the real rules.
static func _verify(board: Array, caps: Array, sol: Array) -> bool:
	var t: Array = board.duplicate(true)
	for mv in sol:
		var a: int = mv[0]
		var b: int = mv[1]
		if not Rules.can_move(t, caps, a, b):
			return false
		Rules.apply_move(t, a, b)
	return Rules.count_crystals(t) == 0


static func verify(level: Dictionary) -> bool:
	return _verify(level["board"], level["caps"], level["solution"])


# ── reverse operations ────────────────────────────────────────────────────────

# Can `c` be pushed onto tube i without breaking capacity or making a run of 3?
# Workspace tubes (index >= fcount) only ever hold one or two crystals of one colour.
static func _push_ok(tubes: Array, caps: Array, fcount: int, i: int, c: int) -> bool:
	var t: Array = tubes[i]
	if t.size() + 1 > int(caps[i]):
		return false
	if i >= fcount:
		if t.size() + 1 > 2:
			return false
		if not t.is_empty() and t[t.size() - 1] != c:
			return false
		return true
	if t.is_empty():
		return true
	if t[t.size() - 1] == c:
		return Rules.top_run(t) + 1 <= 2
	return true


# Reverse of a clearing move: puts a pair on one tube and the third crystal on another.
# With want_casc a triple of another colour is buried under the pair, or under the
# crystal that will be lifted off, so the forward move triggers a cascade.
static func _op_add(tubes: Array, caps: Array, fcount: int, need: Array, k: int, rng: Array, moves: Array, want_casc: bool) -> int:
	var cols: Array = []
	for c in range(k):
		if need[c] > 0:
			cols.append(c)
	_shuffle(rng, cols)
	if not want_casc:
		for c in cols:
			if _add_plain(tubes, caps, fcount, need, c, rng, moves):
				return 1
		return 0
	var kind: int = _rnd(rng, 2)
	for c in cols:
		if kind == 0:
			var r1: int = _add_pair_over(tubes, caps, fcount, need, k, c, rng, moves)
			if r1 > 0:
				return r1
		else:
			if _add_move_over(tubes, caps, fcount, need, c, rng, moves):
				return 1
	return 0


static func _add_plain(tubes: Array, caps: Array, fcount: int, need: Array, c: int, rng: Array, moves: Array) -> bool:
	var tn: int = tubes.size()
	var js: Array = []
	for q in range(tn):
		js.append(q)
	_shuffle(rng, js)
	for j in js:
		var jt: Array = tubes[j]
		if jt.size() + 3 > int(caps[j]):
			continue
		if j >= fcount and not jt.is_empty():
			continue
		if not jt.is_empty() and jt[jt.size() - 1] == c:
			continue
		var cands: Array = []
		for i in range(tn):
			if i != j and _push_ok(tubes, caps, fcount, i, c):
				cands.append(i)
		if cands.is_empty():
			continue
		var i2: int = cands[_rnd(rng, cands.size())]
		jt.append(c)
		jt.append(c)
		tubes[i2].append(c)
		moves.append([i2, j])
		need[c] -= 1
		return true
	return false


# Pair of colour c sitting on a buried triple of another colour (returns triples added).
static func _add_pair_over(tubes: Array, caps: Array, fcount: int, need: Array, k: int, c: int, rng: Array, moves: Array) -> int:
	var alts: Array = []
	for a in range(k):
		if a != c and need[a] > 0:
			alts.append(a)
	if alts.is_empty():
		return 0
	_shuffle(rng, alts)
	var js: Array = []
	for q in range(fcount):
		js.append(q)
	_shuffle(rng, js)
	for j in js:
		var jt: Array = tubes[j]
		if jt.size() + 6 > int(caps[j]):
			continue
		for a in alts:
			if not jt.is_empty() and jt[jt.size() - 1] == a:
				continue
			var cands: Array = []
			for i in range(tubes.size()):
				if i != j and _push_ok(tubes, caps, fcount, i, c):
					cands.append(i)
			if cands.is_empty():
				continue
			var i2: int = cands[_rnd(rng, cands.size())]
			jt.append(a)
			jt.append(a)
			jt.append(a)
			jt.append(c)
			jt.append(c)
			tubes[i2].append(c)
			moves.append([i2, j])
			need[c] -= 1
			need[a] -= 1
			return 2
	return 0


# Triple of colour a buried under a crystal that the forward move lifts off.
static func _add_move_over(tubes: Array, caps: Array, fcount: int, need: Array, a: int, rng: Array, moves: Array) -> bool:
	var tn: int = tubes.size()
	var srcs: Array = []
	for j in range(tn):
		var t: Array = tubes[j]
		if t.is_empty():
			continue
		if (t.size() == 1 or Rules.top_run(t) == 2) and t[t.size() - 1] != a:
			srcs.append(j)
	_shuffle(rng, srcs)
	for j in srcs:
		var cj: int = tubes[j][tubes[j].size() - 1]
		var dests: Array = []
		for i in range(fcount):
			if i == j:
				continue
			var it: Array = tubes[i]
			if it.size() + 4 > int(caps[i]):
				continue
			if not it.is_empty() and it[it.size() - 1] == a:
				continue
			dests.append(i)
		if dests.is_empty():
			continue
		var i2: int = dests[_rnd(rng, dests.size())]
		tubes[j].pop_back()
		tubes[i2].append(a)
		tubes[i2].append(a)
		tubes[i2].append(a)
		tubes[i2].append(cj)
		moves.append([i2, j])
		need[a] -= 1
		return true
	return false


# Reverse of a plain move: lifts a crystal off a pair / single and drops it elsewhere.
static func _op_move(tubes: Array, caps: Array, fcount: int, rng: Array, moves: Array) -> bool:
	var tn: int = tubes.size()
	var srcs: Array = []
	for j in range(tn):
		var t: Array = tubes[j]
		if not t.is_empty() and (t.size() == 1 or Rules.top_run(t) == 2):
			srcs.append(j)
	_shuffle(rng, srcs)
	for j in srcs:
		var c: int = tubes[j][tubes[j].size() - 1]
		var dests: Array = []
		for i in range(tn):
			if i == j:
				continue
			if not _push_ok(tubes, caps, fcount, i, c):
				continue
			if tubes[j].size() == 1 and tubes[i].is_empty():
				continue
			dests.append(i)
		if dests.is_empty():
			continue
		var i2: int = dests[_rnd(rng, dests.size())]
		tubes[j].pop_back()
		tubes[i2].append(c)
		moves.append([i2, j])
		return true
	return false


# Gold crystals anywhere; mystery crystals only below the top of a tube.
static func _apply_flags(tubes: Array, gold: int, myst: int, rng: Array) -> void:
	var cells: Array = []
	for i in range(tubes.size()):
		for j in range(tubes[i].size()):
			cells.append([i, j])
	_shuffle(rng, cells)
	var g_left: int = gold
	for p in cells:
		if g_left <= 0:
			break
		tubes[p[0]][p[1]] = tubes[p[0]][p[1]] | 32
		g_left -= 1
	var m_left: int = myst
	for p in cells:
		if m_left <= 0:
			break
		var t: Array = tubes[p[0]]
		if p[1] >= t.size() - 1:
			continue
		if (t[p[1]] & 32) != 0:
			continue
		t[p[1]] = t[p[1]] | 16
		m_left -= 1


# ── tiny deterministic PRNG (identical on every platform) ─────────────────────

static func _next(rng: Array) -> int:
	var s: int = (int(rng[0]) * 1103515245 + 12345) & 0x7fffffff
	rng[0] = s
	return s >> 8


static func _rnd(rng: Array, n: int) -> int:
	return _next(rng) % n


static func _shuffle(rng: Array, a: Array) -> void:
	var i: int = a.size() - 1
	while i > 0:
		var j: int = _rnd(rng, i + 1)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
		i -= 1
