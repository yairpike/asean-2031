class_name RTSLoc
extends RefCounted
## Localization helper on top of TranslationServer: t(key, {params}) with {name}
## placeholders, bind(node, key) remembers the key so refresh_tree() re-renders
## all bound texts after a live language switch, missing_keys() for QA.

const META: StringName = &"rts_loc"

static func t(key: String, params: Dictionary = {}) -> String:
	var text: String = String(TranslationServer.translate(StringName(key)))
	return text.format(params) if not params.is_empty() else text

static func bind(node: Object, key: String, params: Dictionary = {}, property: String = "text") -> void:
	if node == null:
		return
	var entries: Dictionary = node.get_meta(META, {})
	entries[property] = [key, params]
	node.set_meta(META, entries)
	if node is Node:
		(node as Node).auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.set(property, t(key, params))

## Re-applies every bound text under `root` (call after set_language()).
static func refresh_tree(root: Node) -> int:
	var n: int = 0
	if root.has_meta(META):
		var entries: Dictionary = root.get_meta(META)
		for prop: String in entries:
			root.set(prop, t(str(entries[prop][0]), entries[prop][1]))
			n += 1
	for c: Node in root.get_children():
		n += refresh_tree(c)
	return n

static func set_language(locale: String, root: Node = null) -> int:
	TranslationServer.set_locale(locale)
	return refresh_tree(root) if root != null else 0

## Keys present in `reference` locale but missing in `locale`.
static func missing_keys(locale: String, reference: String = "en") -> Array[String]:
	var ref_keys: Array[String] = []
	var have: Dictionary[String, bool] = {}
	for tr: Translation in _translations():
		for k: StringName in tr.get_message_list():
			if tr.locale == reference:
				ref_keys.append(str(k))
			elif tr.locale == locale:
				have[str(k)] = true
	var out: Array[String] = []
	for k: String in ref_keys:
		if not have.has(k):
			out.append(k)
	return out

static func _translations() -> Array[Translation]:
	var out: Array[Translation] = []
	for p: String in ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()):
		var tr: Translation = load(p) as Translation
		if tr != null:
			out.append(tr)
	return out
