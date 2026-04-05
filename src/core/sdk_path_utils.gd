@tool
extends RefCounted
## Path Utils Tools

static func normalize_res_path(path: String) -> String:
	if path.is_empty():
		return path
	path = path.strip_edges()
	while path.begins_with("res://res://"):
		path = path.substr(6)
	if not path.begins_with("res://") and not path.begins_with("user://"):
		path = "res://" + path
	path = path.replace("\\", "/")
	var protocol := ""
	var rest := path
	if path.begins_with("res://"):
		protocol = "res://"
		rest = path.substr(6)
	elif path.begins_with("user://"):
		protocol = "user://"
		rest = path.substr(7)
	while "//" in rest:
		rest = rest.replace("//", "/")
	return protocol + rest

static func is_resource_path(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("user://")

static func resource_exists(path: String) -> bool:
	return ResourceLoader.exists(normalize_res_path(path))

static func ensure_dir(dir_path: String) -> bool:
	if DirAccess.dir_exists_absolute(dir_path):
		return true
	return DirAccess.make_dir_recursive_absolute(dir_path) == OK
