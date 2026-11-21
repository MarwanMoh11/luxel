class_name LxPalette
extends RefCounted
## The 20 Last Light colours (docs/art_concepts/lastlight/core.py).
## Every UI pixel uses only these 20 opaque colours; fades step through palette ramps, never alpha.

const HEX: Dictionary = {
	"void": "#0d0b1e",
	"night": "#211a3b",
	"dusk": "#3d2c5c",
	"plum": "#6a3d6f",
	"wine": "#a0466a",
	"coral": "#e2725b",
	"apricot": "#f5a96a",
	"gold": "#ffd98c",
	"cream": "#fff4dc",
	"pine": "#1d3d4c",
	"teal": "#2b6b68",
	"jade": "#4c9e78",
	"lime": "#a3cf7d",
	"deep": "#263873",
	"blue": "#3e6db0",
	"sky": "#78a9da",
	"ice": "#c7e5ef",
	"mauve": "#8a6e91",
	"stone": "#c2a7ae",
	"rose": "#ec9fa8",
}

const PAL: Dictionary = {
	"void": Color("0d0b1e"),
	"night": Color("211a3b"),
	"dusk": Color("3d2c5c"),
	"plum": Color("6a3d6f"),
	"wine": Color("a0466a"),
	"coral": Color("e2725b"),
	"apricot": Color("f5a96a"),
	"gold": Color("ffd98c"),
	"cream": Color("fff4dc"),
	"pine": Color("1d3d4c"),
	"teal": Color("2b6b68"),
	"jade": Color("4c9e78"),
	"lime": Color("a3cf7d"),
	"deep": Color("263873"),
	"blue": Color("3e6db0"),
	"sky": Color("78a9da"),
	"ice": Color("c7e5ef"),
	"mauve": Color("8a6e91"),
	"stone": Color("c2a7ae"),
	"rose": Color("ec9fa8"),
}

const FADE_RAMP: Array[String] = ["void", "dusk", "mauve", "stone", "cream"]

const COLOR_RAMPS: Dictionary = {
	"cream": ["void", "dusk", "mauve", "stone", "cream"],
	"gold": ["void", "dusk", "plum", "apricot", "gold"],
	"ice": ["void", "deep", "blue", "sky", "ice"],
	"stone": ["void", "night", "dusk", "mauve", "stone"],
	"mauve": ["void", "night", "dusk", "mauve"],
	"coral": ["void", "dusk", "plum", "wine", "coral"],
	"apricot": ["void", "dusk", "wine", "coral", "apricot"],
	"lime": ["void", "pine", "teal", "jade", "lime"],
	"sky": ["void", "deep", "blue", "sky"],
	"rose": ["void", "dusk", "plum", "wine", "rose"],
}

const CURSOR_COLORS: Array[String] = [
	"gold",
	"cream",
	"ice",
	"lime",
	"coral",
	"rose",
	"sky",
	"apricot",
]


static func color(name: String, fallback: String = "cream") -> Color:
	if PAL.has(name):
		return PAL[name] as Color
	return PAL[fallback] as Color


static func is_valid_color(name: String) -> bool:
	return PAL.has(name)


## Steps from hidden (t <= 0) up through the palette ramp to the target colour (t >= 1).
## Returns Color(0, 0, 0, 0) only when fully hidden; every visible step is 100% opaque.
static func fade_step(t: float, colour_name: String = "cream") -> Color:
	if t <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var ramp: Array = COLOR_RAMPS.get(colour_name, FADE_RAMP) as Array
	var n: int = ramp.size()
	if n <= 0:
		return color(colour_name)
	var idx: int = clampi(floori(clampf(t, 0.0, 1.0) * float(n)), 0, n - 1)
	if idx == 0 and str(ramp[0]) == "void" and t < 0.08:
		return Color(0.0, 0.0, 0.0, 0.0)
	return color(str(ramp[idx]))
