@tool
extends RefCounted
## Runtime schema generation from ClassDB

const Result = preload("../core/sdk_result.gd")
const NodeRules = preload("./node_rules.gd")

const VARIANT_TYPE_MAP := {
	TYPE_BOOL: "bool",
	TYPE_INT: "int",
	TYPE_FLOAT: "float",
	TYPE_STRING: "String",
	TYPE_VECTOR2: "Vector2",
	TYPE_VECTOR2I: "Vector2i",
	TYPE_VECTOR3: "Vector3",
	TYPE_VECTOR3I: "Vector3i",
	TYPE_RECT2: "Rect2",
	TYPE_RECT2I: "Rect2i",
	TYPE_TRANSFORM2D: "Transform2D",
	TYPE_TRANSFORM3D: "Transform3D",
	TYPE_COLOR: "Color",
	TYPE_NODE_PATH: "NodePath",
	TYPE_STRING_NAME: "StringName",
	TYPE_OBJECT: "Object",
	TYPE_ARRAY: "Array",
	TYPE_DICTIONARY: "Dictionary",
	TYPE_PACKED_BYTE_ARRAY: "PackedByteArray",
	TYPE_PACKED_INT32_ARRAY: "PackedInt32Array",
	TYPE_PACKED_INT64_ARRAY: "PackedInt64Array",
	TYPE_PACKED_FLOAT32_ARRAY: "PackedFloat32Array",
	TYPE_PACKED_FLOAT64_ARRAY: "PackedFloat64Array",
	TYPE_PACKED_STRING_ARRAY: "PackedStringArray",
	TYPE_PACKED_VECTOR2_ARRAY: "PackedVector2Array",
	TYPE_PACKED_VECTOR3_ARRAY: "PackedVector3Array",
	TYPE_PACKED_COLOR_ARRAY: "PackedColorArray",
}


static func _get_godot_version() -> String:
	var info := Engine.get_version_info()
	return "%s.%s.%s" % [info["major"], info["minor"], info["patch"]]


static func _get_inheritance_chain(type_name: String) -> Array:
	var chain: Array = []
	var current := ClassDB.get_parent_class(type_name)
	while not current.is_empty():
		chain.append(String(current))
		current = ClassDB.get_parent_class(current)
	return chain


static func _classify_node_type(type_name: String) -> String:
	if ClassDB.is_parent_class(type_name, "Node3D"):
		return "3D"
	if ClassDB.is_parent_class(type_name, "Control"):
		return "UI"
	if ClassDB.is_parent_class(type_name, "Node2D"):
		return "2D"
	return "Other"


static func _get_instantiable_subtypes(base_type: String) -> Array:
	var result: Array = []
	for cls in ClassDB.get_class_list():
		if ClassDB.is_parent_class(cls, base_type) and ClassDB.can_instantiate(cls):
			result.append(String(cls))
	result.sort()
	return result


static func _property_to_schema(prop: Dictionary) -> Dictionary:
	var schema := {}
	var variant_type: int = prop.get("type", TYPE_NIL)
	var hint: int = prop.get("hint", PROPERTY_HINT_NONE)
	var hint_string: String = prop.get("hint_string", "")

	if hint == PROPERTY_HINT_ENUM:
		schema["type"] = "enum"
		var values: Array = []
		for entry in hint_string.split(","):
			var parts := entry.split(":")
			values.append(parts[0].strip_edges())
		schema["values"] = values
		return schema

	if hint == PROPERTY_HINT_FLAGS:
		schema["type"] = "flags"
		var flags: Array = []
		for entry in hint_string.split(","):
			flags.append(entry.strip_edges())
		schema["flags"] = flags
		return schema

	if hint == PROPERTY_HINT_RANGE and not hint_string.is_empty():
		var base_type: String = VARIANT_TYPE_MAP.get(variant_type, "Variant")
		schema["type"] = base_type
		var parts := hint_string.split(",")
		if parts.size() >= 2:
			schema["range"] = {"min": float(parts[0]), "max": float(parts[1])}
			if parts.size() >= 3:
				schema["range"]["step"] = float(parts[2])
		return schema

	if hint == PROPERTY_HINT_RESOURCE_TYPE and not hint_string.is_empty():
		schema["type"] = "Resource"
		schema["resource_type"] = hint_string
		var subtypes := _get_instantiable_subtypes(hint_string)
		if not subtypes.is_empty():
			schema["inline_types"] = subtypes
		return schema

	if hint == PROPERTY_HINT_FILE:
		schema["type"] = "String"
		schema["hint"] = "file"
		if not hint_string.is_empty():
			schema["filter"] = hint_string
		return schema

	if hint == PROPERTY_HINT_DIR:
		schema["type"] = "String"
		schema["hint"] = "dir"
		return schema

	if variant_type == TYPE_OBJECT:
		var class_name_str: String = str(prop.get("class_name", ""))
		schema["type"] = class_name_str if not class_name_str.is_empty() else "Object"
		return schema

	schema["type"] = VARIANT_TYPE_MAP.get(variant_type, "Variant")
	return schema


static func get_node_schema(type_name: String, include_inherited: bool = false) -> Dictionary:
	if not ClassDB.class_exists(type_name):
		return Result.err("Unknown type: %s" % type_name, "ERR_UNKNOWN_TYPE")
	if not ClassDB.is_parent_class(type_name, "Node") and type_name != "Node":
		return Result.err("%s is not a Node subclass" % type_name, "ERR_NOT_NODE_TYPE")

	var inherits := _get_inheritance_chain(type_name)

	# Build property ownership map when include_inherited is true
	var property_owners := {}
	if include_inherited:
		var chain: Array = [type_name]
		chain.append_array(inherits)
		for cls in chain:
			for prop in ClassDB.class_get_property_list(cls, true):
				var pname: String = str(prop.name)
				if not property_owners.has(pname):
					property_owners[pname] = String(cls)

	var prop_list := ClassDB.class_get_property_list(type_name, not include_inherited)
	var properties := {}
	for prop in prop_list:
		var usage: int = prop.get("usage", 0)
		if usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		if usage & PROPERTY_USAGE_INTERNAL != 0:
			continue
		var pname: String = str(prop.name)
		if pname in ["script", "resource_path", "resource_name"]:
			continue
		var entry := _property_to_schema(prop)
		if include_inherited and property_owners.has(pname) and property_owners[pname] != type_name:
			entry["inherited_from"] = property_owners[pname]
		properties[pname] = entry

	var data := {
		"godot_version": _get_godot_version(),
		"type": type_name,
		"inherits": inherits,
		"properties": properties,
	}

	var required_children := NodeRules.get_required_children(type_name)
	if not required_children.is_empty():
		var rc_list: Array = []
		for rc in required_children:
			rc_list.append({"type": rc["type"], "reason": rc["reason"]})
		data["required_children"] = rc_list

	var warnings := NodeRules.get_warnings(type_name)
	if not warnings.is_empty():
		data["warnings"] = warnings

	return Result.ok(data)


static func get_supported_node_types() -> Dictionary:
	var types: Array = []
	for cls in ClassDB.get_class_list():
		var cls_str := String(cls)
		if cls_str == "Node" or (ClassDB.is_parent_class(cls_str, "Node") and ClassDB.can_instantiate(cls_str)):
			types.append({
				"name": cls_str,
				"inherits": String(ClassDB.get_parent_class(cls_str)),
				"category": _classify_node_type(cls_str),
			})
	types.sort_custom(func(a, b): return a["name"] < b["name"])
	return Result.ok({"types": types})
