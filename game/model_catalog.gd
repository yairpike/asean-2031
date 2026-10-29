extends RefCounted
## Per-model data the registry applies on mount: forward-yaw corrections and building materials.
## Game forward is -Z. Every yaw here was checked on a facing sheet (tools/facing_sheet.gd).

## Rigged Tripo bipeds come out of the retarget facing +X; toe bones measured per model.
const RIGGED_YAW: Dictionary = {}

## Static Tripo game models (game/models/tripo/ or the store's models-tripo set).
const TRIPO_YAW: Dictionary = {}

## Older stand-in models in game/models/.
const STANDIN_YAW: Dictionary = {}

static func forward_yaw_deg(id: String, path: String) -> float:
	if path.contains("/rigged/"):
		return float(RIGGED_YAW.get(id, 0.0))
	if path.contains("/tripo/") or path.contains("models-tripo"):
		return float(TRIPO_YAW.get(id, 0.0))
	return float(STANDIN_YAW.get(id, 0.0))
