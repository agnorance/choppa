class_name Baked
extends RefCounted
## Procedural textures (gauge dial, canopy cracks, muzzle star, scorch mark, smoke puff)
## are drawn by GDScript code next to the things that use them, but drawing them pixel
## by pixel at every start costs seconds on a phone. tools/bake_textures.gd draws them
## once into assets/textures/baked/*.png (committed, VRAM-compressed on import) and
## the game loads those. A missing PNG is drawn on the spot, so a new texture works
## before its first bake; run tools/bake.ps1 (or bake.sh) to add it.

const DIR := "res://assets/textures/baked/"

static var _cache := {}


## Every baked texture: name -> function returning the Image to bake.
static func generators() -> Dictionary:
	return {
		"puff": Effects._soft_dot_image,
		"smoke": Effects.smoke_image,
		"muzzle_star": Effects.star_image,
		"glass_cracks": Effects.crack_image,
		"scorch": Effects.scorch_image,
		"dial": Cockpit.dial_image,
		"glint": Cockpit._glint_image,
	}


static func texture(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".png"
	var texture: Texture2D
	if ResourceLoader.exists(path):
		texture = load(path)
	else:
		push_warning("No baked texture '%s'; drawing it now. Run tools/bake.ps1 to bake it." % name)
		var image: Image = generators()[name].call()
		image.generate_mipmaps()
		texture = ImageTexture.create_from_image(image)
	_cache[name] = texture
	return texture
