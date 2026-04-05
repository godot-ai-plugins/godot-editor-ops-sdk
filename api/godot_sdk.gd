@tool
class_name GodotSDK
extends RefCounted

## Unified entry point that aggregates all modules
## Can be called via GodotSDK.scene.create_scene_from_json()
## Or directly via SceneOps.create_scene_from_json()

static var fs := FileSystem
static var scene := SceneOps
static var scripts := ScriptOps
static var resource := ResourceOps
static var config := ProjectConfig
static var editor := EditorOps
static var validate := ValidationOps
