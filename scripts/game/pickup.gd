class_name Pickup
extends RefCounted
## A risk/reward item that appears BEHIND the player. You must look back to grab it.

enum Kind { LANTERN, RELIC, WARD }
const GRAB_TIME := 0.45

var kind: int = Kind.LANTERN
var off := 130.0   ## distance behind the runner (px)
var grab := 0.0    ## seconds spent looking at it
var age := 0.0


func color() -> Color:
	match kind:
		Kind.LANTERN:
			return Color(1.0, 0.68, 0.24)
		Kind.RELIC:
			return Color(0.75, 0.48, 1.0)
	return Color(0.33, 0.9, 1.0)


func label() -> String:
	match kind:
		Kind.LANTERN:
			return "LANTERN"
		Kind.RELIC:
			return "RELIC"
	return "WARD"
