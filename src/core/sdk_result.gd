@tool
class_name SDKResult
extends RefCounted

static func ok(data: Variant = null) -> Dictionary:
	return {"ok": true, "data": data}

static func err(message: String, code: String = "", context: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "error": message, "code": code}
	if not context.is_empty():
		result["context"] = context
	return result
