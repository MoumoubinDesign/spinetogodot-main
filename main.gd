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
		_update_visual()

var _switch_name: String = ""
@export var 切换名: String:
	get:
		return _switch_name
	set(value):
		_switch_name = value
		_update_visual()

func _ready():
	_update_visual()

func set_skin(skin_name: String) -> void:
	_current_skin = skin_name
	_update_visual()

func apply_skin_data(skin_name: String) -> void:
	_current_skin = skin_name
	_update_visual()

func _update_visual() -> void:
	var skin_mgr = _find_skin_manager()
	if skin_mgr and skin_mgr.has_method("update_slot_visual"):
		skin_mgr.call("update_slot_visual", self, name, _switch_name)

func _find_skin_manager() -> Node:
	var p = get_parent()
	while p:
		var mgr = p.get_node_or_null("SpineToGodotSkinManager")
		if mgr:
			return mgr
		for child in p.get_children():
			if child is SpineToGodotSkinManager or child.name == "SpineToGodotSkinManager":
				return child
		p = p.get_parent()
	return null
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

## 图集页面纹理字典 { "xxx.png": Texture2D }
@export var textures: Dictionary = {}

## 全量皮肤切片与网格数据包
@export var skins_data: Dictionary = {}

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
	_init_textures()
	apply_skin(_current_skin)

## 自动初始化并发现各图集页面纹理
func _init_textures() -> void:
	var root = get_parent()
	if not root:
		return
	
	var visuals = root.get_node_or_null("Visuals")
	if visuals:
		for child in visuals.get_children():
			if child is Sprite2D and child.texture is AtlasTexture:
				var a_tex = child.texture as AtlasTexture
				if a_tex.atlas:
					var p_name = a_tex.atlas.resource_path.get_file()
					if p_name != "" and not textures.has(p_name):
						textures[p_name] = a_tex.atlas
			elif child is Polygon2D and child.texture:
				var p_name = child.texture.resource_path.get_file()
				if p_name != "" and not textures.has(p_name):
					textures[p_name] = child.texture
	
	var base_dir = ""
	for k in textures:
		if textures[k] is Texture2D and textures[k].resource_path != "":
			base_dir = textures[k].resource_path.get_base_dir()
			break
	if base_dir == "" and root.scene_file_path != "":
		base_dir = root.scene_file_path.get_base_dir()
	
	if base_dir != "":
		if not base_dir.ends_with("/"):
			base_dir += "/"
		for sk in skins_data:
			for slot_name in skins_data[sk]:
				for att_name in skins_data[sk][slot_name]:
					var page_name = skins_data[sk][slot_name][att_name].get("page", "")
					if page_name != "" and not textures.has(page_name):
						var full_path = base_dir + page_name
						if ResourceLoader.exists(full_path):
							var loaded = load(full_path)
							if loaded is Texture2D:
								textures[page_name] = loaded

## 代码换装接口：调用 set_skin("皮肤名") 即可一秒切换皮肤
func set_skin(skin_name: String) -> void:
	if _current_skin != skin_name:
		_current_skin = skin_name
	apply_skin(skin_name)

## 应用皮肤到所有插槽
func apply_skin(skin_name: String) -> void:
	_current_skin = skin_name
	if textures.is_empty():
		_init_textures()
	var root = get_parent()
	if root:
		_update_slots_recursive(root, skin_name)

func _update_slots_recursive(node: Node, skin_name: String) -> void:
	if node == self:
		return
	if node.has_method("apply_skin_data"):
		node.call("apply_skin_data", skin_name)
	elif node.has_method("set_skin"):
		node.call("set_skin", skin_name)
	
	for child in node.get_children():
		if child != self:
			_update_slots_recursive(child, skin_name)

## 单插槽动态置换引擎
func update_slot_visual(slot_node: Node, slot_name: String, attachment_name: String) -> void:
	var skin_name = _current_skin
	var att_data = _find_attachment_data(skin_name, slot_name, attachment_name)
	
	var remote: RemoteTransform2D = slot_node.get_node_or_null("Remote_Visual") as RemoteTransform2D
	if not remote:
		for child in slot_node.get_children():
			if child is RemoteTransform2D:
				remote = child
				break
	
	if not remote:
		return
	
	var visual_node = remote.get_node_or_null(remote.remote_path)
	if not visual_node:
		return
	
	if att_data.is_empty():
		visual_node.visible = false
		return
	
	var page_name = att_data.get("page", "")
	var raw_tex = textures.get(page_name, null)
	var tex: Texture2D = null
	if raw_tex is Texture2D:
		tex = raw_tex
	elif raw_tex is String and raw_tex != "":
		if ResourceLoader.exists(raw_tex):
			var loaded = ResourceLoader.load(raw_tex)
			if loaded is Texture2D:
				tex = loaded
	
	if not tex and page_name != "":
		_init_textures()
		if textures.has(page_name) and textures[page_name] is Texture2D:
			tex = textures[page_name]
	
	var att_type = att_data.get("type", "region")
	
	if visual_node is Sprite2D:
		var atlas_tex = visual_node.texture as AtlasTexture
		if not atlas_tex:
			atlas_tex = AtlasTexture.new()
			visual_node.texture = atlas_tex
		
		if tex:
			atlas_tex.atlas = tex
		atlas_tex.region = att_data.get("region", Rect2())
		atlas_tex.margin = att_data.get("margin", Rect2())
		
		remote.position = att_data.get("position", Vector2.ZERO)
		remote.rotation_degrees = att_data.get("rotation", 0.0)
		remote.scale = att_data.get("scale", Vector2.ONE)
		visual_node.visible = true
		
	elif visual_node is Polygon2D:
		if tex:
			visual_node.texture = tex
		visual_node.texture_offset = att_data.get("texture_offset", Vector2.ZERO)
		visual_node.uv = att_data.get("uv", PackedVector2Array())
		visual_node.polygon = att_data.get("polygon", PackedVector2Array())
		visual_node.polygons = att_data.get("polygons", [])
		if att_data.has("bones"):
			visual_node.bones = att_data["bones"]
		if att_data.has("internal_vertex_count"):
			visual_node.internal_vertex_count = att_data["internal_vertex_count"]
		visual_node.visible = true

func _find_attachment_data(skin_name: String, slot_name: String, att_name: String) -> Dictionary:
	if skins_data.is_empty():
		return {}
	
	var search_skins = [skin_name]
	if skin_name != "default":
		search_skins.append("default")
	
	for sk in search_skins:
		if skins_data.has(sk) and skins_data[sk].has(slot_name):
			var slot_atts: Dictionary = skins_data[sk][slot_name]
			if att_name != "":
				if slot_atts.has(att_name):
					return slot_atts[att_name]
				var clean_target = _clean_name(att_name)
				for k in slot_atts:
					if _clean_name(k) == clean_target:
						return slot_atts[k]
			else:
				for k in slot_atts:
					return slot_atts[k]
					
	return {}

func _clean_name(name_str: String) -> String:
	if name_str.is_empty():
		return ""
	var base = name_str
	var slash_pos = base.rfind("/")
	if slash_pos != -1:
		base = base.substr(slash_pos + 1)
	return base
"""
		file.store_string(default_content)
		file.close()
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
	
