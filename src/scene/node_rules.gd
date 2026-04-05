@tool
extends RefCounted
## Node constraint rule system

## 2D physics bodies require a CollisionShape2D child node.
const PHYSICS_BODY_2D_TYPES := ["CharacterBody2D", "RigidBody2D", "StaticBody2D", "Area2D"]
## 3D physics bodies require a CollisionShape3D child node.
const PHYSICS_BODY_3D_TYPES := ["CharacterBody3D", "RigidBody3D", "StaticBody3D", "Area3D"]

## Rules that only issue warnings and do not auto-complete
const WARN_ONLY_RULES := {
	"GPUParticles2D": {"property": "process_material", "resource_type": "ParticleProcessMaterial"},
	"GPUParticles3D": {"property": "process_material", "resource_type": "ParticleProcessMaterial"},
	"NavigationRegion2D": {"property": "navigation_polygon", "resource_type": "NavigationPolygon"},
	"NavigationRegion3D": {"property": "navigation_mesh", "resource_type": "NavigationMesh"},
}

## Check whether a node requires auto-completion of child nodes. 
## Returns the list of child nodes that need to be completed
static func get_required_children(node_type: String) -> Array:
	if node_type in PHYSICS_BODY_2D_TYPES:
		return [{
			"type": "CollisionShape2D",
			"name": "CollisionShape2D",
			"shape": _get_default_shape_2d(node_type),
			"reason": "%s requires a collision shape" % node_type
		}]
	if node_type in PHYSICS_BODY_3D_TYPES:
		return [{
			"type": "CollisionShape3D",
			"name": "CollisionShape3D",
			"shape": _get_default_shape_3d(node_type),
			"reason": "%s requires a collision shape" % node_type
		}]
	return []

## Check whether the node's child nodes already contain the specified type.
static func has_child_of_type(children: Array, type_name: String) -> bool:
	for child in children:
		if child is Dictionary and child.get("type", "") == type_name:
			return true
	return false

## Recursively apply constraint rules to the entire scene tree, returning the auto-completion records.
static func apply_rules_recursive(node_data: Dictionary, parent_path: String = "") -> Array:
	var auto_completed: Array = []
	var node_type: String = node_data.get("type", "")
	var node_name: String = node_data.get("name", node_type)
	var current_path := parent_path + "/" + node_name if not parent_path.is_empty() else node_name

	if not node_data.has("children"):
		node_data["children"] = []

	var required := get_required_children(node_type)
	for req in required:
		if not has_child_of_type(node_data["children"], req["type"]):
			var child_data := {
				"name": req["name"],
				"type": req["type"],
				"properties": {}
			}
			# default config: shape
			if req.has("shape"):
				child_data["properties"]["shape"] = req["shape"]
			node_data["children"].append(child_data)
			auto_completed.append({
				"parent": current_path,
				"added": req["name"],
				"reason": req["reason"]
			})

	# Recursively process child nodes.
	for child in node_data["children"]:
		if child is Dictionary:
			auto_completed.append_array(apply_rules_recursive(child, current_path))

	return auto_completed

## Get the default collision shape configuration for 2D.
static func _get_default_shape_2d(_node_type: String) -> Dictionary:
	return {"_type": "RectangleShape2D", "size": {"_type": "Vector2", "x": 32, "y": 32}}

## Get the default collision shape configuration for 3D.
static func _get_default_shape_3d(node_type: String) -> Dictionary:
	if node_type == "CharacterBody3D":
		return {"_type": "CapsuleShape3D", "radius": 0.5, "height": 2.0}
	return {"_type": "BoxShape3D", "size": {"_type": "Vector3", "x": 1, "y": 1, "z": 1}}

## Get rules that only issue warnings (for use with ValidationOps)
static func get_warnings(node_type: String) -> Array:
	if WARN_ONLY_RULES.has(node_type):
		var rule: Dictionary = WARN_ONLY_RULES[node_type]
		return [{
			"property": rule["property"],
			"resource_type": rule["resource_type"],
			"message": "%s needs a %s to function" % [node_type, rule["resource_type"]]
		}]
	return []
