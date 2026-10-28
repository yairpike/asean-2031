# Unit and structure models

Drop a file here and the match uses it instead of the procedural mesh.

`res://game/models/<id>.glb` or `res://game/models/<id>.gltf`

`<id>` is the unit id (`militia`, `amber_tank`) or the building id (`barracks`, `war_factory`). A structure spawned as `Built_barracks` looks up `barracks`. Anything else uses the node name in lower case, so the yard block looks for `playeryard`. A missing file keeps the procedural mesh.

## Space

- 1 unit = 1 metre.
- Up is +Y.
- Forward is -Z, the same axis the procedural meshes face. Do not export the model facing +Z.

The game measures the procedural mesh, then uniformly scales the model so its horizontal footprint fits inside that mesh, and sits the model's base on the procedural mesh's lowest point.

## Optional nodes

These names are case-sensitive. Leave them out when the unit has no moving part.

| Node | Where it sits | What the game does |
| --- | --- | --- |
| `Turret` | Direct child of the scene root | Parented to `Body` and yawed toward the target |
| `Barrel` | Child of `Turret` | Yaws with the turret |
| `Rotor` | Direct child of the scene root | Spun while the unit is alive |
| `Wake` | Direct child of the scene root | Shown while a boat is moving |

## Web budget

The web build is one download. Stay inside this per file:

- Units: 1,500 triangles, one material, one 512×512 albedo.
- Structures: 3,000 triangles, one material, one 1024×512 or 512×512 albedo.
- At most two textures. A packed roughness/metal map counts as the second.
- UVs on every face, 0–1 per surface is enough. Vertex color is optional.

The procedural meshes already store a UV on each face. Their material multiplies that vertex color by an albedo texture when one is assigned, so a painted texture can be dropped on later without rebuilding the mesh.
