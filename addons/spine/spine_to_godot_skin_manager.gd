@tool
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
	
	# 1. 从 Visuals 子节点中收集已绑定的 Texture
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
	
	# 2. 对多页图集，根据当前已有纹理所在目录自动补充载入其余页面
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
	
	# 如果 textures 字典中暂时未找到该 page，尝试按目录补载
	if not tex and page_name != "":
		_init_textures()
		if textures.has(page_name) and textures[page_name] is Texture2D:
			tex = textures[page_name]
	
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
