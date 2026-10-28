# Unit and structure models

Drop a file here and the match uses it instead of the procedural mesh.

`res://game/models/<id>.glb` or `res://game/models/<id>.gltf`

`<id>` is the unit id (`militia`, `amber_tank`) or the building id (`barracks`, `war_factory`). A structure spawned as `Built_barracks` looks up `barracks`. Anything else uses the node name in lower case, so the yard block looks for `playeryard`. A missing file keeps the procedural mesh.

## Space

- 1 unit = 1 metre.
- Up is +Y.
- Forward is -Z, the same axis the procedural meshes face. Do not export the model facing +Z.

The game measures the procedural mesh, then uniformly scales the model so its horizontal footprint fits inside that mesh, and sits the model's base on the procedural mesh's lowest point. A `Wake` node is left out of that measurement so foam behind a hull does not shrink the boat.

## Optional nodes

These names are case-sensitive. Leave them out when the unit has no moving part.

| Node | Where it sits | What the game does |
| --- | --- | --- |
| `Turret` | Direct child of the scene root | Parented to `Body` and yawed toward the target |
| `Barrel` | Child of `Turret` | Yaws with the turret |
| `Rotor` | Direct child of the scene root | Spun while the unit is alive |
| `Wake` | Direct child of the scene root | Shown while a boat is moving |

## Budget

The stand-ins in this folder were built to these limits. Two or three materials are allowed.

- Infantry: 1,500 triangles.
- Vehicles: 3,000 triangles.
- Buildings: 5,000 triangles.

`Body` carries one small grey palette so the faction primary can multiply it. `Trim` is a flat accent. `Wake` is white foam.

## Faction colour

`Body` is multiplied by the faction primary. MVD's charcoal and Black Market's near-black are lifted first, so they do not multiply down to plain grey. `Trim` is set to the faction accent. A model with no `Trim` surface keeps the primary on every other surface. `Wake` is not recolored.

## Web

`.glb` and `.gltf` files in this folder are left out of the web pack. The export copies them to `models/` beside the page, with `models/index.txt`. The page does not download them at startup. A match fetches the index, then each file, and writes it under `user://models/`. The procedural mesh stays in place until that file is on disk.

CC0 stand-in credits are in `CREDITS.md` next to the models.
