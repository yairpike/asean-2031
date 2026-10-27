class_name RTSSelectionBox
extends Control
## Drag-selection rectangle with a live "N units" tag next to the cursor.
## Presentation only (ignores mouse input). Set `count_provider` to a
## Callable(Rect2) -> int; it is called at most once per frame while dragging.

const FILL: Color = Color(0.45, 0.85, 1.0, 0.12)
const FRAME: Color = Color(0.55, 0.92, 1.0, 0.95)

var count_provider: Callable
var active: bool = false
var start: Vector2 = Vector2.ZERO
var current: Vector2 = Vector2.ZERO
var count: int = 0
var tag: Label = Label.new()
var _dirty: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_constant_override("outline_size", 4)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	tag.visible = false
	add_child(tag)

func begin(at: Vector2) -> void:
	active = true
	start = at
	current = at
	_dirty = true
	queue_redraw()

func update_drag(at: Vector2) -> void:
	if active:
		current = at
		_dirty = true
		queue_redraw()

func end() -> void:
	active = false
	tag.visible = false
	queue_redraw()

func rect() -> Rect2:
	return Rect2(start, current - start).abs()

func is_box() -> bool:
	return active and rect().size.length() >= RTSSelection.MIN_BOX_PX

## Recomputes the count and tag text; called from _process, callable from tests.
func refresh() -> void:
	_dirty = false
	count = int(count_provider.call(rect())) if is_box() and count_provider.is_valid() else 0
	tag.visible = is_box()
	if tag.visible:
		tag.text = RTSLoc.t("UI_DRAG_COUNT_ONE" if count == 1 else "UI_DRAG_COUNT", {"count": count})
		tag.position = current + Vector2(14, 14)

func _process(_delta: float) -> void:
	if _dirty:
		refresh()

func _draw() -> void:
	if not is_box():
		return
	var b: Rect2 = rect()
	draw_rect(b, FILL, true)
	draw_rect(b, FRAME, false, 2.0)
