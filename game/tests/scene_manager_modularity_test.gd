extends Node

const FACADE_PATH := "res://scripts/managers/scene_manager.gd"
const MODULE_DIR := "res://scripts/scene_runtime"
const FACADE_LINE_BUDGET := 1800
const MODULE_LINE_BUDGET := 1500

const REQUIRED_MODULES := [
	"SceneUiController",
	"WorldChatController",
	"GardenSceneController",
	"MemorySceneController",
	"SceneNavigationController",
	"FishpondSceneController",
	"RoomSceneController",
	"TravelSceneController",
	"FamilySocialController",
]

const REQUIRED_COMPATIBILITY_METHODS := [
	"setup",
	"goto_scene",
	"open_global_map",
	"open_travel_map",
	"open_memory_creator",
	"open_world_chat",
	"open_family_tree",
	"open_family_members",
	"_show_garden",
	"_build_fishpond",
	"_enter_house",
	"_open_memory_archive",
	"_open_room_draft_preview",
	"_resolve_photo_url",
	"_show_toast",
]

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	_test_facade_contract()
	_test_runtime_modules()
	_test_file_budgets()
	if failures.is_empty():
		print("SceneManager modularity tests passed: facade, modules and line budgets")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	get_tree().quit(1)

func _test_facade_contract() -> void:
	for method in REQUIRED_COMPATIBILITY_METHODS:
		_assert(SceneManager.has_method(method), "SceneManager 兼容门面缺少方法：%s" % method)
	_assert(SceneManager.GAME_SIZE == Vector2(1280, 720), "SceneManager 应继续公开 GAME_SIZE")
	_assert(SceneManager.ASSETS is Dictionary, "SceneManager 应继续公开 ASSETS")
	_assert(SceneManager.mode is String, "SceneManager 应继续公开场景状态")

func _test_runtime_modules() -> void:
	for module_name in REQUIRED_MODULES:
		var module := SceneManager.get_node_or_null(module_name)
		_assert(module != null, "SceneManager 缺少内部模块：%s" % module_name)
		_assert(get_node_or_null("/root/%s" % module_name) == null, "%s 不得注册为额外 autoload" % module_name)

func _test_file_budgets() -> void:
	var facade_lines := _line_count(FACADE_PATH)
	_assert(facade_lines > 0 and facade_lines <= FACADE_LINE_BUDGET,
		"SceneManager 门面超过 %d 行预算，当前 %d 行" % [FACADE_LINE_BUDGET, facade_lines])
	var directory := DirAccess.open(MODULE_DIR)
	_assert(directory != null, "缺少 SceneManager 内部模块目录")
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.ends_with("_controller.gd"):
			var path := "%s/%s" % [MODULE_DIR, file_name]
			var line_count := _line_count(path)
			_assert(line_count > 0 and line_count <= MODULE_LINE_BUDGET,
				"内部模块 %s 超过 %d 行预算，当前 %d 行" % [file_name, MODULE_LINE_BUDGET, line_count])
		file_name = directory.get_next()
	directory.list_dir_end()

func _line_count(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var count := 0
	while not file.eof_reached():
		file.get_line()
		count += 1
	return maxi(0, count - 1)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
