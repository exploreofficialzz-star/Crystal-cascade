class_name BoardLayout
extends RefCounted

# Where every tube stands. Up to 6 tubes sit in ONE row (nothing can hide a tube
# behind another). 7-10 tubes use two staggered rows: the back row stands on a
# raised tier and every back tube sits in the gap between two front tubes, so
# every tube stays visible and tappable. New tubes are always appended at the
# end of the layout (end of the row, or end of the back row).

const SX_WIDE := 2.2
const BACK_DZ := 3.0
const RISER := 1.2

# Returns {"pos": Array[Vector3] (x, riser height, z), "rows": int, "front": int, "half_w": float}
static func compute(n: int) -> Dictionary:
	var pos: Array = []
	var rows := 1
	var front := n
	if n <= 6:
		var sx := 2.15 if n <= 4 else 2.05
		for i in range(n):
			pos.append(Vector3((float(i) - float(n - 1) / 2.0) * sx, 0.0, 0.0))
	else:
		rows = 2
		front = int(ceil(float(n) / 2.0))
		var back := n - front
		var shift := 0.25 * SX_WIDE if front == back else 0.0
		for i in range(front):
			pos.append(Vector3((float(i) - float(front - 1) / 2.0) * SX_WIDE - shift, 0.0, BACK_DZ * 0.5))
		for j in range(back):
			pos.append(Vector3((float(j) - float(back - 1) / 2.0) * SX_WIDE + shift, RISER, -BACK_DZ * 0.5))
	var max_x := 0.0
	for p in pos:
		var v: Vector3 = p
		max_x = maxf(max_x, absf(v.x))
	return {"pos": pos, "rows": rows, "front": front, "half_w": max_x + 1.0}
