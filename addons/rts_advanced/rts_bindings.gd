class_name RTSBindings
extends RefCounted
## Default RTS key bindings registered into the InputMap, with rebinding,
## conflict detection, save/load to a ConfigFile and human-readable labels.

const DEFAULTS: Dictionary[StringName, Key] = {
	&"rts_pan_left": KEY_A, &"rts_pan_right": KEY_D, &"rts_pan_up": KEY_W, &"rts_pan_down": KEY_S,
	&"rts_stop": KEY_X, &"rts_attack_move": KEY_Q, &"rts_formation_line": KEY_F,
	&"rts_produce": KEY_B, &"rts_cancel_production": KEY_C, &"rts_select_all": KEY_E,
}

## Registers every default action that is missing (existing ones are kept).
static func install() -> void:
	for a: StringName in DEFAULTS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			_set_key(a, DEFAULTS[a])

static func key_of(action: StringName) -> Key:
	if not InputMap.has_action(action):
		return KEY_NONE
	for e: InputEvent in InputMap.action_get_events(action):
		var k: InputEventKey = e as InputEventKey
		if k != null:
			return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	return KEY_NONE

## Action already using `key`, or &"" if free.
static func conflict(key: Key, except: StringName = &"") -> StringName:
	for a: StringName in DEFAULTS:
		if a != except and key_of(a) == key:
			return a
	return &""

## Rebinds; refuses (returns the conflicting action) if the key is taken.
static func rebind(action: StringName, key: Key) -> StringName:
	var c: StringName = conflict(key, action)
	if c != &"":
		return c
	_set_key(action, key)
	return &""

static func reset() -> void:
	for a: StringName in DEFAULTS:
		if InputMap.has_action(a):
			_set_key(a, DEFAULTS[a])

static func label(action: StringName) -> String:
	return OS.get_keycode_string(key_of(action))

static func save(path: String) -> Error:
	var cf: ConfigFile = ConfigFile.new()
	for a: StringName in DEFAULTS:
		cf.set_value("keys", str(a), int(key_of(a)))
	return cf.save(path)

static func load_from(path: String) -> Error:
	var cf: ConfigFile = ConfigFile.new()
	var err: Error = cf.load(path)
	if err != OK:
		return err
	for a: StringName in DEFAULTS:
		if cf.has_section_key("keys", str(a)):
			_set_key(a, cf.get_value("keys", str(a)) as Key)
	return OK

static func _set_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
