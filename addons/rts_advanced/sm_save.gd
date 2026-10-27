class_name SMSave
extends RefCounted
## Finished story missions, one id per line in user://campaign.save.

const PATH: String = "user://campaign.save"

static func clear() -> void:
	var abs_path: String = ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(abs_path)

static func finished() -> PackedStringArray:
	if not FileAccess.file_exists(PATH):
		return PackedStringArray()
	var out: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(PATH).split("\n", false):
		var id: String = line.strip_edges()
		if id != "" and not out.has(id):
			out.append(id)
	return out

static func has(id: String) -> bool:
	return finished().has(id)

static func mark(id: String) -> void:
	if id == "" or not SMCampaign.ids().has(id) or has(id):
		return
	var have: PackedStringArray = finished()
	have.append(id)
	var handle: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if handle == null:
		return
	for item: String in have:
		handle.store_line(item)
	handle.close()
