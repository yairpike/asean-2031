extends RefCounted
## Webp art served beside the page, outside the pack.
## Desktop and headless runs also read res:// and build/web/.

static var _cache: Dictionary = {}

static func texture(rel: String) -> Texture2D:
	if not _ok(rel):
		return null
	if _cache.has(rel):
		return _cache[rel] as Texture2D
	var bytes: PackedByteArray = _read(rel)
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_webp_from_buffer(bytes) != OK:
		return null
	var tex := ImageTexture.create_from_image(image)
	_cache[rel] = tex
	return tex

static func _ok(rel: String) -> bool:
	return rel.ends_with(".webp") and not rel.contains("..") and not rel.begins_with("/") and not rel.contains("\\")

static func _read(rel: String) -> PackedByteArray:
	var packed: String = "res://%s" % rel
	if FileAccess.file_exists(packed):
		return FileAccess.get_file_as_bytes(packed)
	var roots: PackedStringArray = PackedStringArray()
	roots.append(ProjectSettings.globalize_path("res://").path_join("build/web"))
	roots.append(OS.get_executable_path().get_base_dir())
	for root: String in roots:
		var path: String = root.path_join(rel)
		if FileAccess.file_exists(path):
			return FileAccess.get_file_as_bytes(path)
	return PackedByteArray()
