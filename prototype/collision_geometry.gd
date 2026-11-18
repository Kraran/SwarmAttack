extends RefCounted

const EPSILON := 0.00001
# Les retours par les bords sont des réapparitions, pas des traversées du terrain.
const MAX_CONTINUOUS_STEP := 24.0

static func continuous(from: Vector2, to: Vector2) -> bool:
	return from.distance_squared_to(to) <= MAX_CONTINUOUS_STEP * MAX_CONTINUOUS_STEP


# Premier contact avec un rectangle de pixels [position, end[. INF = aucun.
static func sweep_time(from: Vector2, to: Vector2, bounds: Rect2) -> float:
	var enter := 0.0
	var leave := 1.0
	var delta := to - from
	for axis in 2:
		var low: float = bounds.position[axis]
		var high: float = bounds.end[axis] - EPSILON
		if absf(delta[axis]) < EPSILON:
			if from[axis] < low or from[axis] > high:
				return INF
			continue
		var first: float = (low - from[axis]) / delta[axis]
		var last: float = (high - from[axis]) / delta[axis]
		enter = maxf(enter, minf(first, last))
		leave = minf(leave, maxf(first, last))
		if enter > leave:
			return INF
	return enter
