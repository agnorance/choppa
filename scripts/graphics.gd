class_name Graphics
extends RefCounted
## Graphics quality, picked per platform on first use. Maps and effects ask it how much
## detail to spend. (A settings menu can set `quality` later.)
## HIGH targets desktop GPUs from an RTX 3060 up: SDFGI, SSIL, SSR, volumetric fog,
## dense terrain. MEDIUM is for phones, LOW for the Compatibility fallback.

enum Quality { LOW, MEDIUM, HIGH }

static var quality: Quality = _detect()


static func at_least(level: Quality) -> bool:
	return quality >= level


static func _detect() -> Quality:
	if DisplayServer.get_name() == "headless":
		return Quality.LOW  # Tests: keep generated meshes small.
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		return Quality.LOW  # Fallback renderer: no SSAO, volumetrics, etc.
	if OS.has_feature("mobile"):
		return Quality.MEDIUM
	return Quality.HIGH
