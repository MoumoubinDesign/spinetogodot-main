extends Control


@onready var spine_json: Node = $SpineJson


func _ready() -> void:
	get_window().files_dropped.connect(_on_files_dropped)


func _on_button_2_pressed() -> void:
	# json目录按钮
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.json")
	dialog.popup(Rect2i(200, 200, 500, 400))
	dialog.connect("file_selected", on_选择路径_file_selected)
	dialog.set_title("选择Json文件")

func on_选择路径_file_selected(path: String):
	%JsonPath.text = path

func _on_选择atlas_pressed() -> void:
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.atlas")
	dialog.popup(Rect2i(200, 200, 500, 400))
	dialog.connect("file_selected", on_选择路径atlas_file_selected)
	dialog.set_title("选择atlas图集文件")

func on_选择路径atlas_file_selected(path: String):
	%AtlasPath.text = path

func _on_选择输出_pressed() -> void:
	# 保存文件目录按钮
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	#dialog.file_mode = FileDialog.FILE_MODE_OPEN_ANY
	dialog.popup(Rect2i(200, 200, 500, 400))
	dialog.add_filter("*.tscn")
	dialog.connect("file_selected", on_选择输出_file_selected)
	dialog.set_title("保存文件")

func on_选择输出_file_selected(path: String):
	%ReturnPath.text = path

func _on_button_pressed() -> void:
	# 保存文件目录按钮
	spine_json.res图像路径 = %ResPath.text
	spine_json.atlas路径 = %AtlasPath.text
	spine_json.保存文件(%JsonPath.text,%ReturnPath.text)


func _on_button_3_pressed() -> void:
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.popup(Rect2i(200, 200, 500, 400))
	dialog.connect("dir_selected", on_安装脚本_dir_selected)
	dialog.set_title("定位到所需工程目录")

func on_安装脚本_dir_selected(path: String):
	var dir = DirAccess.open(path)
	if not dir.dir_exists("/addons/spine/"):
		dir.make_dir_recursive(path+"/addons/spine/")
	
	# 检查文件是否存在
	if not FileAccess.file_exists(path+"/addons/spine/spine_to_godot_slot.gd"):
		var file = FileAccess.open(path+"/addons/spine/spine_to_godot_slot.gd", FileAccess.WRITE)
		var default_content = """@tool
class_name SpineToGodotSlot
extends Node2D

var _current_skin: String = "default"
@export var 当前皮肤: String:
	get:
		return _current_skin
	set(value):
		if _current_skin == value:
			return
		_current_skin = value
		_update_visibility()

var _switch_name: String = ""
@export var 切换名: String:
	get:
		return _switch_name
	set(value):
		if _switch_name == value:
			return
		_switch_name = value
		_update_visibility()

func _ready():
	_update_visibility()

func set_skin(skin_name: String) -> void:
	if _current_skin != skin_name:
		_current_skin = skin_name
		_update_visibility()

func _clean_name(name_str: String) -> String:
	if name_str.is_empty():
		return ""
	var base = name_str
	var slash_pos = base.rfind("/")
	if slash_pos != -1:
		base = base.substr(slash_pos + 1)
	return base

func _update_visibility():
	var children = get_children()
	if children.is_empty():
		return

	var best_match_remote: RemoteTransform2D = null
	var fallback_match_remote: RemoteTransform2D = null
	var skin_match_remote: RemoteTransform2D = null
	var default_remote: RemoteTransform2D = null

	var clean_slot_att = _clean_name(_switch_name)

	for child in children:
		if child is RemoteTransform2D:
			var raw_name = child.name.trim_prefix("Remote_").trim_prefix("Slot_")
			var parts = raw_name.split("__")
			var item_skin = ""
			var item_att = ""
			if parts.size() >= 2:
				item_skin = parts[0]
				item_att = "__".join(parts.slice(1))
			else:
				item_skin = "default"
				item_att = raw_name

			var clean_item_att = _clean_name(item_att)

			if _switch_name != "" and (item_att == _switch_name or clean_item_att == clean_slot_att):
				if item_skin == _current_skin:
					best_match_remote = child
				elif item_skin == "default":
					fallback_match_remote = child
			
			if item_skin == _current_skin and skin_match_remote == null:
				skin_match_remote = child
			elif item_skin == "default" and default_remote == null:
				default_remote = child

	var chosen_remote = best_match_remote
	if chosen_remote == null:
		chosen_remote = fallback_match_remote
	if chosen_remote == null:
		chosen_remote = skin_match_remote if skin_match_remote != null else default_remote

	for child in children:
		if child is RemoteTransform2D:
			var target_node = child.get_node_or_null(child.remote_path)
			if target_node:
				target_node.visible = (child == chosen_remote)
"""
		file.store_string(default_content)
		file.close()

	if not FileAccess.file_exists(path+"/addons/spine/插槽.gd"):
		var file = FileAccess.open(path+"/addons/spine/插槽.gd", FileAccess.WRITE)
		var default_content = """@tool
class_name 插槽
extends SpineToGodotSlot
"""
		file.store_string(default_content)
		file.close()
	
	# 检查文件是否存在
	if not FileAccess.file_exists(path+"/addons/spine/spine_to_godot_skin_manager.gd"):
		var file = FileAccess.open(path+"/addons/spine/spine_to_godot_skin_manager.gd", FileAccess.WRITE)
		var default_content = """@tool
class_name SpineToGodotSkinManager
extends Node

## 可用的皮肤列表
@export var available_skins: Array[String] = ["default"]:
	set(value):
		available_skins = value
		notify_property_list_changed()

## 当前激活的皮肤
var _current_skin: String = "default"

var current_skin: String:
	get:
		return _current_skin
	set(value):
		if _current_skin == value:
			return
		_current_skin = value
		apply_skin(value)

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	var enum_string = ",".join(available_skins)
	properties.append({
		"name": "current_skin",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": enum_string,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	return properties

func _ready() -> void:
	apply_skin(_current_skin)

## 代码换装接口：调用 set_skin("皮肤名") 即可一秒切换皮肤
func set_skin(skin_name: String) -> void:
	if _current_skin != skin_name:
		_current_skin = skin_name
	apply_skin(skin_name)

## 应用皮肤到所有插槽
func apply_skin(skin_name: String) -> void:
	_current_skin = skin_name
	var root = get_parent()
	if root:
		_update_slots_recursive(root, skin_name)

func _update_slots_recursive(node: Node, skin_name: String) -> void:
	if node == self:
		return
	if node is 插槽 or node.has_method("set_skin"):
		node.set_skin(skin_name)
	for child in node.get_children():
		if child != self:
			_update_slots_recursive(child, skin_name)
"""
		file.store_string(default_content)
		file.close()

	# 检查文件是否存在
	if not FileAccess.file_exists(path+"/addons/spine/no_rotation.gd"):
		var file = FileAccess.open(path+"/addons/spine/no_rotation.gd", FileAccess.WRITE)
		var default_content = """
@tool
class_name NoRotation extends Node2D

@export var 旋转:bool = true
@export var 缩放:bool = true

func _process(_delta: float) -> void:
	if not 旋转:
		get_parent().global_rotation = rotation
	if not 缩放:
		get_parent().global_scale = scale
		"""
		file.store_string(default_content)
		file.close()



func _on_批量转换_pressed() -> void:
	spine_json.使用atlas图集 = true
	var path = %"LineEdit_批量路径".text
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var n = 0
		while file_name != "":
			if dir.current_is_dir():
				print("发现目录：" + file_name)
				var json路径 = path + file_name + "/" + file_name + ".json"
				spine_json.res图像路径 = "res://" + file_name + "/"
				spine_json.atlas路径 = path + file_name + "/" + file_name + ".atlas"
				var 导出路径 = path + file_name + "/" + file_name + ".tscn"
				spine_json.保存文件(json路径,导出路径)
				print("已完成："+str(n))
				n += 1
			else:
				print("发现文件" + file_name)
			file_name = dir.get_next()
	else:
		print("尝试访问路径时出错。")


func _on_预览_pressed() -> void:
	spine_json.res图像路径 = %ResPath.text
	spine_json.atlas路径 = %AtlasPath.text
	Global.根节点 = spine_json.预览文件(%JsonPath.text)
	get_tree().get_root().gui_embed_subwindows = false
	var w = preload("res://Spine编辑器/编辑器窗口.tscn").instantiate()
	w.gui_embed_subwindows = false
	add_child(w)
	


func _on_files_dropped(files):
	for i in files:
		var path:String = i
		if path.get_extension() == "json":
			%JsonPath.text = path
		if path.get_extension() == "atlas":
			%AtlasPath.text = path
			%ReturnPath.text = path.get_basename() + ".tscn"
			
	print(files)
	
