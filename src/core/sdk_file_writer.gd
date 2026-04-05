@tool
class_name SDKFileWriter
extends RefCounted
## File Write Implementation

static var _scan_scheduled := false

static func write_text(path: String, content: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.close()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().update_file(path)
		_schedule_scan()
	return true

static func write_scene(root_node: Node, path: String, overwrite: bool = false) -> Dictionary:
	if not path.begins_with("res://"):
		path = "res://" + path
	if ResourceLoader.exists(path) and not overwrite:
		return {"ok": false, "error": "File already exists: %s" % path}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var packed := PackedScene.new()
	var result := packed.pack(root_node)
	if result != OK:
		return {"ok": false, "error": "Pack failed: %d" % result}
	var err := ResourceSaver.save(packed, path)
	if err != OK:
		return {"ok": false, "error": "Save failed: %d" % err}
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().update_file(path)
		_schedule_scan()
	return {"ok": true}

static func _schedule_scan() -> void:
	if _scan_scheduled:
		return
	_scan_scheduled = true
	if Engine.is_editor_hint():
		Callable(SDKFileWriter, "_do_scan").call_deferred()

static func _do_scan() -> void:
	_scan_scheduled = false
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
