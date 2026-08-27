class_name AddonsTemplates

const PLUGIN_CFG = """[plugin]

name="Spine"
description="转换json文件为场景"
author="柯哀的眼"
version="1.0"
script="spine.gd"
"""

const NO_ROTATION_GD = """@tool
class_name NoRotation extends Node2D

@export var 旋转:bool = true
@export var 缩放:bool = true


func _process(_delta: float) -> void:
	if not 旋转:
		get_parent().global_rotation = rotation
	if not 缩放:
		get_parent().global_scale = scale
"""

const SLOT_ALIAS_GD = """@tool
class_name 插槽
extends SpineToGodotSlot
"""

const SPINE_TO_GODOT_SLOT_GD = """@tool
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
		# 若自身父节点即为包含管理器的根节点
		for child in p.get_children():
			if child is SpineToGodotSkinManager or child.name == "SpineToGodotSkinManager":
				return child
		p = p.get_parent()
	return null
"""

const SPINE_TO_GODOT_SKIN_MANAGER_GD = """@tool
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
"""

const SPINE_PLUGIN_GD = """@tool
extends EditorPlugin

var node_2d: Node2D

var 图片路径 = ""
var json路径 = ""

var popup_menu = null

func _enter_tree():
	var fs_dock: = get_editor_interface().get_file_system_dock()

	var popup_menus = []
	for n in fs_dock.get_children():
		if n is PopupMenu:
			popup_menus.push_back(n)
	
	self.popup_menu = popup_menus[-1]
	self.popup_menu.connect("menu_changed", Callable(self, "on_context_menu_changed"))
	self.popup_menu.connect("id_pressed", Callable(self, "on_context_menu_id_pressed"))


func on_context_menu_changed():
	if self.popup_menu.item_count == 0:
		return
	var name = self.popup_menu.get_item_text(self.popup_menu.item_count - 1)
	var cur_path:String = get_editor_interface().get_current_path()
	if not cur_path: return
	
	var ext = cur_path.get_extension()
	if name == "Open":
		if ext == "json":
			self.popup_menu.add_separator()
			self.popup_menu.add_item("Spine转换")


func on_context_menu_id_pressed(id:int):
	var cur_path:String = get_editor_interface().get_current_path()
	var ext = cur_path.get_extension()
	if ext != "json":
		return
	if id != 2:
		return
	
	json路径 = cur_path
	
	var viewport = EditorInterface.get_editor_main_screen() 
	var 选择路径Dialog = EditorFileDialog.new()
	viewport.add_child(选择路径Dialog)
	选择路径Dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	选择路径Dialog.popup(Rect2i(200, 200, 1000, 500))
	选择路径Dialog.connect("dir_selected", on_选择路径_dir_selected)
	选择路径Dialog.set_title("选择图片目录")


func _exit_tree():
	pass


func on_选择路径_dir_selected(path: String):
	图片路径 = path + "/"
	print(path)
	
	node_2d = Node2D.new()
	node_2d.name = "Node2D"

	var json = load(json路径)
	var g = 生成骨骼(json)
	var c = 生成插槽(json,g[0],g[1])
	创建动画(json,g[0],g[1],c)
	
	var viewport = EditorInterface.get_editor_main_screen() 
	var fileDialog = EditorFileDialog.new()
	viewport.add_child(fileDialog)
	fileDialog.popup(Rect2i(200, 200, 1000, 500))
	fileDialog.connect("file_selected", on_file_selected)

func on_file_selected(path: String):
	var scene = PackedScene.new()
	scene.pack(node_2d)
	var 导出名 = path.get_file().get_basename()
	var 目录 = path.get_base_dir()
	ResourceSaver.save(scene,目录+"/"+导出名+".tscn")


func sort_ascending(a, b):
	var _a = 0
	var _b = 0
	if a.has("order"):
		_a = a["order"]
	if b.has("order"):
		_b = b["order"]
	if _a < _b:
		return true
	return false

func 生成骨骼(json):
	var k = Skeleton2D.new()
	k.name = "Skeleton2D"
	k.visible = false
	node_2d.add_child(k)
	k.owner = node_2d
	
	var s:Dictionary = {}
	for i in json.data["bones"]:
		var b = Bone2D.new()
		b.set_autocalculate_length_and_angle(false)
		b.rest = Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(0, 0))
		s[i['name']] = b
		b.name = i['name']
		
		if i.has('parent'):
			s[i['parent']].add_child(b)
		else:
			k.add_child(b)
		
		if i.has('length'):
			b.set_length(i['length'])
		
		if i.has("rotation"):
			b.rotation_degrees = i['rotation']*-1
		
		if i.has('transform'):
			if i['transform'] == "noRotationOrReflection":
				if i.has("rotation"):
					b.global_rotation_degrees = i['rotation']*-1
			
		
		var pos = Vector2.ZERO
		if i.has("x"):
			pos.x = i['x']
		if i.has("y"):
			pos.y = i['y']*-1
		b.position = pos
		b.rest = Transform2D(b.rotation, Vector2(b.position.x, b.position.y))
		
		var sca = Vector2.ONE
		if i.has("scaleX"):
			sca.x = i['scaleX']
		if i.has("scaleY"):
			sca.y = i['scaleY']
		b.scale = sca
		b.owner = node_2d
	
	if json.data.has("ik"):
		if json.data["ik"].size() > 0:
			var msk = SkeletonModificationStack2D.new()
			msk.enabled = true
			k.set_modification_stack(msk)
			var ik列表 = json.data["ik"]
			ik列表.sort_custom(sort_ascending)
			for i in ik列表:
				if i.has('bones'):
					var IK骨骼 = i['bones']
					if IK骨骼.size() == 1:
						var lookat = SkeletonModification2DLookAt.new()
						lookat.bone2d_node = k.get_path_to(s[IK骨骼[0]])
						if i.has('target'):
							var IK目标 = i['target']
							lookat.target_nodepath = k.get_path_to(s[IK目标])
						msk.add_modification(lookat)
					elif IK骨骼.size() == 2:
						var towik = SkeletonModification2DTwoBoneIK.new()
						towik.set_joint_one_bone2d_node(k.get_path_to(s[IK骨骼[0]]))
						towik.set_joint_two_bone2d_node(k.get_path_to(s[IK骨骼[1]]))
						var IK名 = i['name']
						if i.has('target'):
							var IK目标 = i['target']
							towik.target_nodepath = k.get_path_to(s[IK目标])
						if i.has('bendPositive'):
							var IK正反 = i['bendPositive']
							towik.flip_bend_direction = IK正反
						else:
							towik.flip_bend_direction = true
						msk.add_modification(towik)
			
	
	return [s,k]

func parse_weights(data: Array) -> Array:
	var result = []
	var i = 0

	while i < data.size():
		var num_bones = data[i]
		var bones_and_weights = []
		i += 1

		for _i in range(num_bones):
			var bone_id = data[i]
			var x = data[i + 1]
			var y = data[i + 2]
			var weight = data[i + 3]
			bones_and_weights.append({"bone_id": bone_id,"x": x,"y": y, "weight": weight})
			i += 4

		result.append(bones_and_weights)
	return result

func 生成插槽(json,s,k):
	var c:Dictionary = {}
	var z = 0
	for i in json.data["slots"]:
		var _c = 插槽.new()
		_c.name = i["name"]
		var p = i["bone"]
		s[p].add_child(_c)
		_c.owner = node_2d
		_c.z_index = z
		_c.z_as_relative = false
		z+=1
		c[i['name']] = _c
		if i.has("color"):
			_c.modulate = Color(i["color"])
	
	var 皮肤 = [0]
	if json.data["skins"].size() > 1:
		皮肤 = [0,1]
	
	for _p in 皮肤:
		var attachments = json.data["skins"][_p]["attachments"]
		for i in attachments:
			var _c = c[i]
			for i2 in attachments[i]:
				var a = attachments[i][i2]
				var _item
				
				if a.has("type"):
					if a["type"] == "mesh":
						var 图片名 = i2
						if a.has('name'):
							图片名 = a['name']
						if a.has("path"):
							图片名 = a["path"]
						var _poly = Polygon2D.new()
						_item = _poly
						_poly.texture = load(图片路径+ 图片名 +".png")
						_poly.name = i2
						_c.add_child(_poly)
						_poly.owner = node_2d
						
						var uvs:PackedVector2Array = []
						var _uvs = a["uvs"]
						var _uvw = a["width"]
						var _uvh = a["height"]
						for _i in range(0, _uvs.size(), 2):
							uvs.append(Vector2(_uvs[_i]*_uvw,_uvs[_i+1]*_uvh))
						_poly.uv = uvs
						
						var 插槽骨名 = ""
						for _i in json.data["slots"]:
							if i == _i["name"]:
								插槽骨名 = _i["bone"]
						var points:PackedVector2Array = []
						var _ver = a["vertices"]
						if _uvs.size() < _ver.size():
							var _weights = parse_weights(_ver)
							for _i in _weights:
								var 骨骼号 = _i[0]["bone_id"]
								var 骨骼数据 = json.data["bones"][骨骼号]
								var 最终坐标 = Vector2(_i[0]["x"],_i[0]["y"])
								while true:
									var 旋转值 = 0
									if 骨骼数据.has("rotation"):
										旋转值 = 骨骼数据['rotation']
									if 骨骼数据.has("transform"):
										if 骨骼数据["transform"] == "noRotationOrReflection":
											旋转值 = s[插槽骨名].rotation_degrees*-1
											print("遇到一个不继承旋转的骨骼")
									var pos = Vector2.ZERO
									if 骨骼数据.has("x"):
										pos.x = 骨骼数据['x']
									if 骨骼数据.has("y"):
										pos.y = 骨骼数据['y']
									var sca = Vector2.ONE
									if 骨骼数据.has("scaleX"):
										sca.x = 骨骼数据['scaleX']
									if 骨骼数据.has("scaleY"):
										sca.y = 骨骼数据['scaleY']
									if 骨骼数据["name"] != 插槽骨名:
										最终坐标 = (最终坐标*sca).rotated(deg_to_rad(旋转值))+pos
									else:
										break
									if 骨骼数据.has("parent"):
										var 父骨名 = 骨骼数据["parent"]
										for _b in json.data["bones"]:
											if _b["name"] == 父骨名:
												骨骼数据 = _b
												break
									else:
										break
								最终坐标.y *= -1
								points.append(最终坐标)
						else:
							for _i in range(0, _ver.size(), 2):
								points.append(Vector2(_ver[_i],_ver[_i+1]*-1))
						_poly.polygon = points
						_poly.internal_vertex_count = _uvs.size()/2-a["hull"]
						
						var trianles = []
						var _triangles = a["triangles"]
						for _i in range(0, _triangles.size(), 3):
							var _t = []
							_t.push_back(_triangles[_i])
							_t.push_back(_triangles[_i+1])
							_t.push_back(_triangles[_i+2])
							trianles.push_back(_t)
						_poly.polygons = trianles
						
						if _uvs.size() < _ver.size():
							_c.owner = null
							_c.reparent(node_2d)
							_c.owner = node_2d
							_poly.owner = node_2d
							_poly.skeleton = _poly.get_path_to(k)

							var _weights = parse_weights(_ver)
						
							var new_bones = []
							var _sn = 0
							for _i in s:
								var new_qz:PackedFloat32Array = []
								for _a in range(_poly.polygon.size()):
									var 权重 = 0.0
									for ii in _weights[_a]:
										if ii['bone_id'] == _sn:
											权重 = ii['weight']
									new_qz.append(权重)
								var _isq = false
								for _q in new_qz:
									if _q != 0:
										_isq = true
								if _isq:
									new_bones.append(k.get_path_to(s[_i]))
									new_bones.append(new_qz)
								_sn += 1
							_poly.bones = new_bones
							var _gp = _poly.global_position
							var _gr = _poly.global_rotation
							_poly.global_position = _gp
							_poly.global_rotation = _gr
						
						_poly.visible = false
						for _i in json.data["slots"]:
							if _i.has("attachment"):
								if _i["attachment"] == i2:
									_poly.visible = true
						
				else:
					var 图片名 = i2
					if a.has('name'):
						图片名 = a['name']
					if a.has("path"):
						图片名 = a["path"]
					var _sprite = Sprite2D.new()
					_item = _sprite
					_sprite.texture = load(图片路径 + 图片名 + ".png")
					_sprite.name = i2
					_c.add_child(_sprite)
					_sprite.owner = node_2d
					
					if a.has("rotation"):
						_sprite.rotation_degrees = a['rotation']*-1
					
					var pos = Vector2.ZERO
					if a.has("x"):
						pos.x = a['x']
					if a.has("y"):
						pos.y = a['y']*-1
					_sprite.position = pos
					
					var sca = Vector2.ONE
					if a.has("scaleX"):
						sca.x = a['scaleX']
					if a.has("scaleY"):
						sca.y = a['scaleY']
					_sprite.scale = sca
					
					_sprite.visible = false
					
					for _i in json.data["slots"]:
						if _i.has("attachment"):
							if _i["attachment"] == i2:
								_sprite.visible = true
				
				if _item:
					for _i in json.data["slots"]:
						if _i.has("blend"):
							var _add = false
							if _i.has("attachment"):
								if _i["attachment"] == i2:
									_add = true
							if _i['name'] == _item.get_parent().name:
								_add = true
							if _add:
								if _i["blend"] == "additive":
									var mat = CanvasItemMaterial.new()
									mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
									_item.material = mat
	return c

func 创建动画(json,s,k,c):
	var animplay = AnimationPlayer.new()
	node_2d.add_child(animplay)
	animplay.owner = node_2d
	animplay.name = "AnimationPlayer"
	
	var al = AnimationLibrary.new()
	var lg_anim = json.data.get('animations', {})
	var autoplay_anim_name = ""
	for i in lg_anim:
		var animation = Animation.new()
		var 动画名 = i
		var 预估时长 = 0
		if lg_anim[i].has("slots"):
			var 插槽动画数据 = lg_anim[i]["slots"]
			for 插槽名 in 插槽动画数据:
				if 插槽动画数据[插槽名].has("color"):
					var 颜色帧 = 插槽动画数据[插槽名]["color"]
					var 插槽径 =  str(node_2d.get_path_to(c[插槽名])) + ":modulate"
					var track_index = animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track_index, 插槽径)
					for _y in 颜色帧:
						var 延迟 = 0
						var 颜色值 = ""
						if _y.has("time"):
							延迟 = _y["time"]
							if 预估时长<延迟:
								预估时长 = 延迟
						if _y.has("color"):
							颜色值 = str(_y["color"])
						animation.track_insert_key(track_index,延迟, Color(颜色值))
				
				if 插槽动画数据[插槽名].has("attachment"):
					var 切换帧 = 插槽动画数据[插槽名]["attachment"]
					
					var 插槽径 =  str(node_2d.get_path_to(c[插槽名])) + ":切换名"
					var track_index = animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track_index, 插槽径)
					animation.value_track_set_update_mode(track_index,Animation.UPDATE_DISCRETE)
					animation.track_set_interpolation_type(track_index,Animation.INTERPOLATION_NEAREST)
					
					for _q in 切换帧:
						var 延迟 = 0
						var 切换值 = ""
						if _q.has("time"):
							延迟 = _q["time"]
							if 预估时长<延迟:
								预估时长 = 延迟
						if _q.has("name"):
							切换值 = str(_q["name"])
						animation.track_insert_key(track_index,延迟, 切换值)
		
		if lg_anim[i].has("deform"):
			var 顶点动画数据 = lg_anim[i]["deform"]["default"]
			for 插槽名 in 顶点动画数据:
				for 网格名 in 顶点动画数据[插槽名]:
					var 顶点帧 = 顶点动画数据[插槽名][网格名]
					var _poly = c[插槽名].find_child(网格名)
					var 顶点径 =  str(node_2d.get_path_to(_poly)) + ":polygon"
					var track_index = animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track_index, 顶点径)
					for _vd in 顶点帧:
						var 延迟 = 0
						var _offset = 0
						var _vertices = _poly.polygon
						if _vd.has('time'):
							延迟 = _vd['time']
							if 预估时长<延迟:
								预估时长 = 延迟
						if _vd.has('offset'):
							_offset = _vd['offset']
						if _vd.has('vertices') and _poly.bones.size() == 0:
							var _vds = _vd['vertices']
							for _o in range(_offset):
								_vds.push_front(0)
							if _vds.size()%2 == 1:
								_vds.push_back(0)
							var _vn = 0
							for _i in range(0, _vds.size(), 2):
								_vertices[_vn] += Vector2(_vds[_i],_vds[_i+1]*-1)
								_vn += 1
						if _vd.has('vertices') and _poly.bones.size() > 0:
							var _vds = _vd['vertices']
							if int(_offset)%2==1:
								_vds.push_front(0)
								_offset-=1
							if _vds.size()%2==1:
								_vds.push_back(0)
							var 权重网格 = json.data['skins'][0]['attachments'][插槽名][网格名]["vertices"]
							var _weights = parse_weights(权重网格)
							var 点数组 = []
							var _wn = 0
							for _w in _weights:
								if _offset <= _wn*2 and (_wn*2-_offset)+1 < _vds.size():
									var 最终坐标 = Vector2(_vds[(_wn*2-_offset)], _vds[(_wn*2-_offset)+1])
									最终坐标.y *= -1
									点数组.append(最终坐标)
								else:
									点数组.append(Vector2(0,0))
								_wn += _w.size()
							
							var _vn = 0
							for _i in 点数组:
								_vertices[_vn] += _i
								_vn += 1
						animation.track_insert_key(track_index,延迟, _vertices)
		
		if lg_anim[i].has("bones"):
			var 骨骼动画数据 = lg_anim[i]["bones"]
			for 骨名 in 骨骼动画数据:
				if 骨骼动画数据[骨名].has("translate"):
					var 原始变换 = s[骨名].position
					var 变换帧 = 骨骼动画数据[骨名]["translate"]
					var 骨路径 =  str(node_2d.get_path_to(s[骨名])) + ":position"
					var track_index = animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track_index, 骨路径)
					for _t in 变换帧:
						var 延迟 = 0
						if _t.has("time"):
							延迟 = _t["time"]
							if 预估时长<延迟:
								预估时长 = 延迟
						var 变换值 = Vector2.ZERO
						if _t.has("x"):
							变换值.x = 原始变换.x + _t["x"]
						else:
							变换值.x = 原始变换.x
						if _t.has("y"):
							变换值.y = 原始变换.y + _t["y"]*-1
						else:
							变换值.y = 原始变换.y
						animation.track_insert_key(track_index,延迟, 变换值)
					
				if 骨骼动画数据[骨名].has("rotate"):
					var 原始旋转值 = s[骨名].rotation_degrees
					var 旋转帧 = 骨骼动画数据[骨名]["rotate"]
					var 骨路径 =  str(node_2d.get_path_to(s[骨名])) + ":rotation"
					var track_index = animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_interpolation_type(track_index,Animation.INTERPOLATION_LINEAR_ANGLE)
					animation.track_set_path(track_index, 骨路径)
					for _r in 旋转帧:
						var 延迟 = 0
						if _r.has("time"):
							延迟 = _r["time"]
							if 预估时长<延迟:
								预估时长 = 延迟
						var 旋转值 = 0
						if _r.has("angle"):
							旋转值 = 原始旋转值 + _r["angle"]*-1
						else:
							旋转值 = 原始旋转值
						animation.track_insert_key(track_index,延迟, deg_to_rad(旋转值))
				
				if 骨骼动画数据[骨名].has("scale"):
					var 原始缩放 = s[骨名].scale
					var 缩放帧 = 骨骼动画数据[骨名]["scale"]
					var 骨路径 =  str(node_2d.get_path_to(s[骨名])) + ":scale"
					var track_index = animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track_index, 骨路径)
					for _s in 缩放帧:
						var 延迟 = 0
						if _s.has("time"):
							延迟 = _s["time"]
							if 预估时长<延迟:
								预估时长 = 延迟
						var 缩放值 = Vector2.ONE
						if _s.has("x"):
							缩放值.x = _s["x"]
						else:
							缩放值.x = 原始缩放.x
						if _s.has("y"):
							缩放值.y = _s["y"]
						else:
							缩放值.y = 原始缩放.y
						animation.track_insert_key(track_index,延迟, 缩放值)
		
		animation.set_length(预估时长)
		
		动画名 = 动画名.replace("[","_")
		动画名 = 动画名.replace("]","_")
		动画名 = 动画名.replace("/","_")
		
		var name_lower = 动画名.to_lower()
		if name_lower == "idel":
			animation.loop_mode = Animation.LOOP_LINEAR
			autoplay_anim_name = "animations/" + 动画名
		elif name_lower == "idle":
			animation.loop_mode = Animation.LOOP_LINEAR
			if autoplay_anim_name == "" or not autoplay_anim_name.to_lower().ends_with("/idel"):
				autoplay_anim_name = "animations/" + 动画名
		
		al.add_animation(动画名,animation)
		
	var anim_library_name = "animations"
	animplay.add_animation_library(anim_library_name,al)
	if autoplay_anim_name != "":
		animplay.autoplay = autoplay_anim_name
	
	var 全局库 = AnimationLibrary.new()
	animplay.add_animation_library("",全局库)
	var global_library = animplay.get_animation_library("")
	var RESET_anim = Animation.new()
	RESET_anim.set_length(0.001)
	global_library.add_animation("RESET", RESET_anim)
	
	for i in c:
		var 插槽径 =  str(node_2d.get_path_to(c[i])) + ":切换名"
		var track_index = RESET_anim.add_track(Animation.TYPE_VALUE)
		RESET_anim.track_set_path(track_index, 插槽径)
		RESET_anim.value_track_set_update_mode(track_index,Animation.UPDATE_DISCRETE)
		RESET_anim.track_set_interpolation_type(track_index,Animation.INTERPOLATION_NEAREST)
		var 子项 = c[i].get_children()
		var 切换名 = ""
		for _i in 子项:
			if _i.visible:
				切换名 = _i.name
		RESET_anim.track_insert_key(track_index,0.0, 切换名)
		
		var 插槽颜色径 =  str(node_2d.get_path_to(c[i])) + ":modulate"
		var track_index2 = RESET_anim.add_track(Animation.TYPE_VALUE)
		RESET_anim.track_set_path(track_index2, 插槽颜色径)
		RESET_anim.track_insert_key(track_index2,0.0, c[i].modulate)
		
	for i in s:
		var 骨骼位置径 =  str(node_2d.get_path_to(s[i])) + ":position"
		var track_index = RESET_anim.add_track(Animation.TYPE_VALUE)
		RESET_anim.track_set_path(track_index, 骨骼位置径)
		RESET_anim.track_insert_key(track_index,0.0, s[i].position)
		
		var 骨骼旋转径 =  str(node_2d.get_path_to(s[i])) + ":rotation"
		var track_index2 = RESET_anim.add_track(Animation.TYPE_VALUE)
		RESET_anim.track_set_path(track_index2, 骨骼旋转径)
		RESET_anim.track_insert_key(track_index2,0.0, s[i].rotation)
		RESET_anim.value_track_set_update_mode(track_index2,Animation.UPDATE_DISCRETE)
		RESET_anim.track_set_interpolation_type(track_index2,Animation.INTERPOLATION_LINEAR_ANGLE)
		
		var 骨骼缩放径 =  str(node_2d.get_path_to(s[i])) + ":scale"
		var track_index3 = RESET_anim.add_track(Animation.TYPE_VALUE)
		RESET_anim.track_set_path(track_index3, 骨骼缩放径)
		RESET_anim.track_insert_key(track_index3,0.0, s[i].scale)
"""

static func get_files() -> Dictionary:
	return {
		"spine_to_godot_slot.gd": SPINE_TO_GODOT_SLOT_GD,
		"插槽.gd": SLOT_ALIAS_GD,
		"spine_to_godot_skin_manager.gd": SPINE_TO_GODOT_SKIN_MANAGER_GD,
		"no_rotation.gd": NO_ROTATION_GD,
		"plugin.cfg": PLUGIN_CFG,
		"spine.gd": SPINE_PLUGIN_GD
	}
