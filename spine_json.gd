extends Node

"""
更新日志
20250808：发现插槽下网格会有隐藏的情况，经过排查，是slots数据中如果插槽含有attachment键，
则显示，否则默认隐藏。
经过再次检查，原因是attachment键会有重名，导致检测bug，不能仅依靠附件名判断，还需要根据插槽名判断

20250808：网格畸形BUG，经过排查发现是因为计算顶点坐标时候父骨骼会参与计算，当骨骼没有父骨骼时网格恢复正常，
并且该网格受到两根骨骼的影响，初步诊断，插槽在骨骼里就会畸变，插槽直接在root中则正常
再次诊断，原因是没有判断一种情况，即顶点权重来自非父骨骼，而是其他同级骨骼
之前陷入了一个误区，spine中插槽不会受到骨骼的影响，仅当骨骼有权重时才会受到变换的影响
当一个骨骼作为插槽父骨骼但没有权重时，移动父骨骼将不会影响网格

20250808：网格畸形BUG,网格顶点计算要考虑多个骨骼影响。目前只实现了单根骨骼
骨骼变换只需要考虑权重骨即可，不需要考虑权重骨的父骨骼

发现BUG，没有权重的网格，会受到骨骼变换影响
20250809：功能缺失：不支持使用连接网格
20250809：核心问题，带权重的网格需不需要继承父层级变换

20250822：拖拽文件直接修改路径
20250825：继承缩放导致骨骼本身缩放被忽略
不继承旋转分情况，有权重和无权重两种情况

20250905:修改网格畸变BUG，每根骨骼的权重需要单独计算
20250905:发现新BUG，不勾选继承旋转后，矩阵计算方式被改变
20250906：使用矩阵彻底解决网格畸变BUG

20250909：发现BUG，root骨骼缩放导致权重网格错误，不支持root缩放的操作

20250910：不继承骨骼的动画部分由RemoteTransform2D节点替代（缺陷：没有考虑不继承缩放和都不继承的情况）
20250911：彻底修复不继承旋转骨骼问题，增加NoRotation

20250913:发现BUG，IK系统如果多个修改器使用同一目标，不能单独设置混合(建议自建IK节点)
20250913：解决动画曲线问题100%还原（缺陷，网格变形轨道无法贝塞尔）
"""


var node_2d: Node2D
var 图片路径 = ""
var res图像路径 = ""
var ext文本 = {}#用于修复场景文件的图片引用路径

var atlas路径 = ""
var 图集数据 = {}
var 图集Image
var 是否浏览 = false

func _ready() -> void:
	pass


func 保存文件(json路径,导出路径):
	是否浏览 = false
	图片路径 = json路径.get_base_dir() + "/"
	node_2d = Node2D.new()
	node_2d.name = "Node2D"
	

	图集数据 = 加载atlas图集(atlas路径)
	
	var json = load(json路径)
	
	# 创建换装管理器
	var all_skin_names: Array[String] = []
	if json.data.has("skins"):
		for sk in json.data["skins"]:
			if sk.has("name"):
				all_skin_names.append(sk["name"])
	if all_skin_names.is_empty():
		all_skin_names = ["default"]

	var skin_mgr = Node.new()
	var skin_script = load("res://addons/spine/spine_to_godot_skin_manager.gd")
	if skin_script:
		skin_mgr.set_script(skin_script)
	skin_mgr.name = "SpineToGodotSkinManager"
	skin_mgr.set("available_skins", all_skin_names)
	skin_mgr.set("current_skin", all_skin_names[0])
	node_2d.add_child(skin_mgr)
	skin_mgr.owner = node_2d

	var g = 生成骨骼(json)
	var c = 生成插槽(json,g[0],g[1])
	创建动画(json,g[0],g[1],c)
	
	var scene = PackedScene.new()
	scene.pack(node_2d)
	ResourceSaver.save(scene,导出路径)
	修复依赖路径(导出路径)


func 预览文件(json路径):
	是否浏览 = true
	图片路径 = json路径.get_base_dir() + "/"
	node_2d = Node2D.new()
	node_2d.name = "Node2D"
	

	图集数据 = 加载atlas图集(atlas路径)
	
	var json = load(json路径)
	
	# 创建换装管理器
	var all_skin_names: Array[String] = []
	if json.data.has("skins"):
		for sk in json.data["skins"]:
			if sk.has("name"):
				all_skin_names.append(sk["name"])
	if all_skin_names.is_empty():
		all_skin_names = ["default"]

	var skin_mgr = Node.new()
	var skin_script = load("res://addons/spine/spine_to_godot_skin_manager.gd")
	if skin_script:
		skin_mgr.set_script(skin_script)
	skin_mgr.name = "SpineToGodotSkinManager"
	skin_mgr.set("available_skins", all_skin_names)
	skin_mgr.set("current_skin", all_skin_names[0])
	node_2d.add_child(skin_mgr)
	skin_mgr.owner = node_2d

	var g = 生成骨骼(json)
	var c = 生成插槽(json,g[0],g[1])
	创建动画(json,g[0],g[1],c)
	return node_2d


func 修复依赖路径(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	var content = file.get_as_text()
	file.close()
	
	# 1. 替换 metadata 占位符为 ExtResource
	content = content.replace("metadata/atlas_path = \"", "atlas = ExtResource(\"")
	content = content.replace("metadata/png_path = \"", "texture = ExtResource(\"")
	content = content.replace(".png_ExtResource\"", ".png\")")
	
	# 2. 清除所有 ext_resource 和场景头部中的本机非法 UID，避免跨项目导入时产生 UID 报错/警告
	var lines = content.split("\n")
	var new_lines = []
	for l in lines:
		var cleaned = l
		if cleaned.begins_with("[ext_resource") or cleaned.begins_with("[gd_scene"):
			var u_start = cleaned.find('uid="uid://')
			if u_start != -1:
				var u_end = cleaned.find('"', u_start + 5)
				if u_end != -1:
					cleaned = cleaned.substr(0, u_start) + cleaned.substr(u_end + 1).strip_edges(true, false)
					cleaned = cleaned.replace("  ", " ")
		new_lines.append(cleaned)
	content = "\n".join(new_lines)
	
	# 3. 收集所有使用的图集 PNG 文件名并插入 Texture2D ExtResource 声明
	var base_res = res图像路径
	if base_res != "" and not base_res.ends_with("/"):
		base_res += "/"
	
	var ext_resources_text = ""
	var pages_to_add: Array = []
	if 图集数据.has("page_names") and 图集数据["page_names"].size() > 0:
		pages_to_add = 图集数据["page_names"]
	elif 图集数据.has("图集图片名") and 图集数据["图集图片名"] != "":
		pages_to_add = [图集数据["图集图片名"]]
	
	for page_name in pages_to_add:
		var img_res_path = base_res + page_name
		if not img_res_path.begins_with("res://"):
			img_res_path = "res://" + img_res_path.trim_prefix("/")
		ext_resources_text += '[ext_resource type="Texture2D" path="{0}" id="{1}"]\n'.format([img_res_path, page_name])
	
	var n = content.find("[sub_resource")
	if n == -1:
		n = content.find("[node")
	if n != -1:
		content = content.insert(n, ext_resources_text)
	
	file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()


func 加载atlas图集(atlas_path: String) -> Dictionary:
	var atlas_dict: Dictionary = {
		"pages": {},
		"regions": {},
		"page_names": []
	}
	
	if not FileAccess.file_exists(atlas_path):
		print("未找到图集文件: ", atlas_path)
		return atlas_dict
	
	var file = FileAccess.open(atlas_path, FileAccess.READ)
	var current_page = ""
	var current_region = ""
	var base_dir = atlas_path.get_base_dir()
	
	while file.get_position() < file.get_length():
		var raw_line = file.get_line()
		var line = raw_line.strip_edges()
		if line.is_empty():
			current_region = ""
			continue
		
		if ":" in line:
			var colon_pos = line.find(":")
			var key = line.substr(0, colon_pos).strip_edges().to_lower()
			var val = line.substr(colon_pos + 1).strip_edges()
			
			if current_region != "" and atlas_dict["regions"].has(current_region):
				var r_data = atlas_dict["regions"][current_region]
				match key:
					"rotate":
						if val.to_lower() == "true":
							r_data["rotate"] = true
						elif val.to_lower() == "false":
							r_data["rotate"] = false
						else:
							r_data["rotate"] = val.to_int()
					"xy":
						var parts = val.split(",")
						if parts.size() >= 2:
							r_data["xy"] = Vector2(parts[0].to_float(), parts[1].to_float())
					"size":
						var parts = val.split(",")
						if parts.size() >= 2:
							r_data["size"] = Vector2(parts[0].to_float(), parts[1].to_float())
					"orig":
						var parts = val.split(",")
						if parts.size() >= 2:
							r_data["orig"] = Vector2(parts[0].to_float(), parts[1].to_float())
					"offset":
						var parts = val.split(",")
						if parts.size() >= 2:
							r_data["offset"] = Vector2(parts[0].to_float(), parts[1].to_float())
					"index":
						r_data["index"] = val.to_int()
			elif current_page != "" and atlas_dict["pages"].has(current_page):
				var p_data = atlas_dict["pages"][current_page]
				match key:
					"size":
						var parts = val.split(",")
						if parts.size() >= 2:
							p_data["size"] = Vector2(parts[0].to_float(), parts[1].to_float())
					"format":
						p_data["format"] = val
					"filter":
						p_data["filter"] = val
					"repeat":
						p_data["repeat"] = val
		else:
			# 没有冒号的行：若以 .png 结尾或尚未有当前页，则为新图集页；否则为切片区域名称
			if line.to_lower().ends_with(".png") or current_page == "":
				current_page = line
				current_region = ""
				if not atlas_dict["pages"].has(current_page):
					atlas_dict["page_names"].append(current_page)
					var p_info = {
						"name": current_page,
						"size": Vector2.ZERO,
						"texture": null
					}
					if 是否浏览:
						var img_path = base_dir + "/" + current_page
						if FileAccess.file_exists(img_path):
							var img_tex = ImageTexture.new()
							var img = Image.load_from_file(img_path)
							if img:
								img_tex.set_image(img)
								p_info["texture"] = img_tex
					atlas_dict["pages"][current_page] = p_info
			else:
				current_region = line
				atlas_dict["regions"][current_region] = {
					"name": current_region,
					"page": current_page,
					"rotate": false,
					"xy": Vector2.ZERO,
					"size": Vector2.ZERO,
					"orig": Vector2.ZERO,
					"offset": Vector2.ZERO,
					"index": -1
				}
				
	file.close()
	if atlas_dict["page_names"].size() > 0:
		atlas_dict["图集图片名"] = atlas_dict["page_names"][0]
	return atlas_dict


# 查找图集中的切片信息，提供智能多级匹配与防崩溃安全回退
func find_atlas_region(atlas_data: Dictionary, skin_name: String, _slot_name: String, att_name: String, att_dict: Dictionary) -> Dictionary:
	if not atlas_data.has("regions"):
		return {}
	var regions: Dictionary = atlas_data["regions"]
	if regions.is_empty():
		return {}
	
	var path_name = att_dict.get("path", "")
	var name_name = att_dict.get("name", "")
	
	var candidates: Array[String] = []
	
	# 优先级 1: path
	if path_name != "":
		candidates.append(path_name)
	# 优先级 2: name
	if name_name != "":
		candidates.append(name_name)
	# 优先级 3: 附件自身名称
	candidates.append(att_name)
	
	# 优先级 4: 带皮肤前缀
	if skin_name != "" and skin_name != "default":
		if path_name != "":
			candidates.append(skin_name + "/" + path_name)
			candidates.append(skin_name + "__" + path_name)
			candidates.append(skin_name + "_" + path_name)
		if name_name != "":
			candidates.append(skin_name + "/" + name_name)
			candidates.append(skin_name + "__" + name_name)
			candidates.append(skin_name + "_" + name_name)
		candidates.append(skin_name + "/" + att_name)
		candidates.append(skin_name + "__" + att_name)
		candidates.append(skin_name + "_" + att_name)
	
	# 优先级 5: 去除前置目录的文件名
	var extra_cands: Array[String] = []
	for c in candidates:
		var base = c.get_file()
		if base != "" and base != c and not extra_cands.has(base):
			extra_cands.append(base)
	candidates.append_array(extra_cands)
	
	# 1. 精确匹配
	for c in candidates:
		if regions.has(c):
			return regions[c]
	
	# 2. 大小写不敏感匹配 / 后缀匹配
	for c in candidates:
		var c_lower = c.to_lower()
		for r_key in regions:
			if r_key.to_lower() == c_lower:
				return regions[r_key]
			if r_key.ends_with("/" + c) or r_key.ends_with("__" + c) or r_key.ends_with("_" + c):
				return regions[r_key]
			if r_key.to_lower().ends_with("/" + c_lower) or r_key.to_lower().ends_with("__" + c_lower):
				return regions[r_key]
				
	print("警告：未在图集中找到切片：", att_name, " (皮肤: ", skin_name, ")")
	
	# 3. 安全回退：返回首个 page 的默认区域，确保生成器绝不崩溃
	var fallback_page = ""
	if atlas_data.has("page_names") and atlas_data["page_names"].size() > 0:
		fallback_page = atlas_data["page_names"][0]
	return {
		"name": att_name,
		"page": fallback_page,
		"rotate": false,
		"xy": Vector2.ZERO,
		"size": Vector2.ONE,
		"orig": Vector2.ONE,
		"offset": Vector2.ZERO,
		"index": -1
	}


# 解析 linkedmesh 继承的父网格数据
func find_parent_mesh(json: Object, current_skin_name: String, slot_name: String, parent_mesh_name: String, parent_skin_name: String = "") -> Dictionary:
	if not json or not json.data.has("skins"):
		return {}
	
	var skins_data = json.data["skins"]
	var search_skins = []
	if parent_skin_name != "":
		search_skins.append(parent_skin_name)
	search_skins.append(current_skin_name)
	search_skins.append("default")
	
	for sk_name in search_skins:
		for sk in skins_data:
			if sk.get("name", "default") == sk_name:
				var atts = sk.get("attachments", {})
				if atts.has(slot_name) and atts[slot_name].has(parent_mesh_name):
					var p_att = atts[slot_name][parent_mesh_name]
					if p_att.get("type", "") == "mesh":
						return p_att
	
	for sk in skins_data:
		var atts = sk.get("attachments", {})
		for s_name in atts:
			if atts[s_name].has(parent_mesh_name):
				var p_att = atts[s_name][parent_mesh_name]
				if p_att.get("type", "") == "mesh":
					return p_att
	return {}


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

# 输入A和B的弧度值，返回新的B值，确保新B与原始B等效，且与A的差值绝对值 ≤ π
func adjust_angle(A: float, B: float) -> float:
	#var TAU = 2 * PI  # 2π
	# 计算B相对于A的等效角度（调整到A的±π范围内）
	var relative_B = fmod(B - A + PI, TAU) - PI
	# 处理边界情况：当结果为 -π 时，转换为 π
	if is_equal_approx(relative_B, -PI):
		relative_B = PI
	# 返回调整后的B（等效于原始B）
	return A + relative_B


func 生成骨骼(json):
	var k = Skeleton2D.new()
	k.name = "Skeleton2D"
	node_2d.add_child(k)
	k.owner = node_2d
	
	var s:Dictionary = {}
	for i in json.data["bones"]:
		var b = Bone2D.new()
		b.set_autocalculate_length_and_angle(false)
		b.rest = Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(0, 0))
		s[i['name']] = b
		b.name = i['name']
		
		if i.has('color'):
			b.self_modulate = i['color']
		
		if i.has('parent'):
			s[i['parent']].add_child(b)
		else:
			k.add_child(b)#说明是root骨骼
		
		if i.has('length'):
			b.set_length(i['length'])
		
		if i.has("rotation"):
			b.rotation_degrees = i['rotation']*-1# 此处未处理不继承旋转的骨骼
			if i.has('transform'):
				if i['transform'] == "noRotationOrReflection":
					b.global_rotation_degrees = i['rotation']*-1
				if i['transform'] == "onlyTranslation":
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
		
		if i.has('transform'):
			var no_rotation = NoRotation.new()
			b.add_child(no_rotation)
			no_rotation.rotation = b.global_rotation
			no_rotation.owner = node_2d
			no_rotation.name = 'NoRotation'
			if i['transform'] == "noRotationOrReflection":
				no_rotation.旋转 = false
			if i['transform'] == "onlyTranslation":
				no_rotation.旋转 = false
				no_rotation.缩放 = false
			if i['transform'] == "noScaleOrReflection":
				no_rotation.缩放 = false
		
	
	# 生成IK
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
						# 只导入两根骨骼的ik
						var towik = SkeletonModification2DTwoBoneIK.new()
						
						towik.set_joint_one_bone2d_node(k.get_path_to(s[IK骨骼[0]]))
						towik.set_joint_two_bone2d_node(k.get_path_to(s[IK骨骼[1]]))
						#var IK名 = i['name']# 没啥用
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
		var num_bones = data[i]  # 当前点参与的骨骼数量
		var bones_and_weights = []
		i += 1  # 移动到骨骼号

		# 遍历每个骨骼号和对应的权重
		for _i in range(num_bones):
			var bone_id = data[i]
			var x = data[i + 1]
			var y = data[i + 2]
			var weight = data[i + 3]
			bones_and_weights.append({"bone_id": bone_id,"x": x,"y": y, "weight": weight})
			i += 4  # 每个骨骼号和权重占用4个位置

		# 将解析后的骨骼和权重加入结果
		result.append(bones_and_weights)
	return result

# 假设 Bone_Data 是你在 JSON 中解析出来的骨骼字典
# 它可以包含 'name', 'parent', 'x', 'y', 'rotation', 'scaleX', 'scaleY', 'transform'
func get_local_transform_matrix(bone_data: Dictionary) -> Transform2D:
	var pos = Vector2.ZERO
	if bone_data.has("x"): pos.x = bone_data["x"]
	if bone_data.has("y"): pos.y = bone_data["y"] # <-- 注意：此处不再乘以 -1
	
	var rot_degrees = 0.0
	if bone_data.has("rotation"): rot_degrees = bone_data["rotation"] # 注意这里不需要 *-1，因为是计算世界变换，最终点Y翻转
	
	var scale = Vector2.ONE
	if bone_data.has("scaleX"): scale.x = bone_data["scaleX"]
	if bone_data.has("scaleY"): scale.y = bone_data["scaleY"]
	
	# 使用 Godot 4 的构造函数创建包含旋转和平移的变换
	var matrix = Transform2D(deg_to_rad(rot_degrees), pos)
	# .scaled() 方法会返回一个新的、经过正确缩放的 Transform2D
	matrix = matrix.scaled(scale)
	return matrix


func calculate_bone_world_matrix(bone_name: String, bone_data_map: Dictionary) -> Transform2D:
	var bone_current_data = bone_data_map[bone_name]
	var local_matrix = get_local_transform_matrix(bone_current_data)
	
	if not bone_current_data.has("parent"):
		# 如果是根骨骼，其世界矩阵就是其局部矩阵
		return local_matrix
	
	var parent_name = bone_current_data["parent"]
	var parent_world_matrix = calculate_bone_world_matrix(parent_name, bone_data_map)
	
	if bone_current_data.has("transform"):
		var transform_mode = bone_current_data["transform"]
		
		# 将局部矩阵的平移、旋转、缩放分量分离出来
		var local_pos = local_matrix.origin
		var local_rot_rad = local_matrix.get_rotation() # 获取弧度
		var local_scale = local_matrix.get_scale()
		
		# 将父世界矩阵的平移、旋转、缩放分量分离出来
		var parent_world_pos = parent_world_matrix.origin
		var parent_world_rot_rad = parent_world_matrix.get_rotation()
		var parent_world_scale = parent_world_matrix.get_scale()

		match transform_mode:
			"noRotationOrReflection":
				# 继承父骨骼的平移和缩放
				var new_pos = parent_world_pos + parent_world_matrix.basis_xform(local_pos)
				var new_scale = parent_world_scale * local_scale
				# 旋转只使用自己的局部旋转
				var new_rot_rad = local_rot_rad
				var final_matrix = Transform2D(new_rot_rad, new_pos)
				return final_matrix.scaled(new_scale)
				
			"onlyTranslation":
				# 只继承父骨骼的平移
				var new_pos = parent_world_pos + parent_world_matrix.basis_xform(local_pos)
				# 旋转和缩放都只使用自己的
				var final_matrix = Transform2D(local_rot_rad, new_pos)
				return final_matrix.scaled(local_scale)
				
			"noScaleOrReflection":
				# 继承父骨骼的缩放和平移
				var new_pos = parent_world_pos + parent_world_matrix.basis_xform(local_pos)
				var new_rot_rad = parent_world_rot_rad + local_rot_rad
				# 缩放只使用自己的局部缩放，忽略父级
				var new_scale = local_scale
				var final_matrix = Transform2D(new_rot_rad, new_pos)
				return final_matrix.scaled(new_scale)
				
			_: # 默认情况（无特殊模式，或者其他未处理的模式）
				# 正常继承所有父级变换
				return parent_world_matrix * local_matrix
	else:
		# 如果没有 transform 模式，正常继承所有父级变换
		return parent_world_matrix * local_matrix



func 生成插槽(json,s,k):
	var visuals = CanvasGroup.new()
	visuals.name = "Visuals"
	node_2d.add_child(visuals)
	visuals.owner = node_2d

	var slot_script = load("res://addons/spine/spine_to_godot_slot.gd")
	if not slot_script:
		slot_script = load("res://addons/spine/插槽.gd")

	# 1. 预先检测哪些插槽包含带权重的网格
	var slot_has_weights: Dictionary = {}
	for s_info in json.data.get("slots", []):
		slot_has_weights[s_info["name"]] = false

	for sk in json.data.get("skins", []):
		var attachments_map = sk.get("attachments", {})
		for slot_name in attachments_map:
			for att_name in attachments_map[slot_name]:
				var a_info = attachments_map[slot_name][att_name]
				if a_info.has("type") and a_info["type"] == "mesh":
					var _uvs_check = a_info.get("uvs", [])
					var _ver_check = a_info.get("vertices", [])
					if _uvs_check.size() < _ver_check.size():
						slot_has_weights[slot_name] = true

	# 2. 在骨骼节点下创建【插槽】(插槽保留在骨骼下并显式绑定脚本)
	var c: Dictionary = {}
	for i in json.data["slots"]:
		var _c = Node2D.new()
		if slot_script:
			_c.set_script(slot_script)
		_c.name = i["name"]
		var p = i["bone"] # 父骨骼
		s[p].add_child(_c)
		_c.owner = node_2d
		c[i['name']] = _c
		if i.has("color"):
			_c.modulate = Color(i["color"])

	# 3. 按照 slots 的声明顺序遍历并创建所有皮肤的附件，确保 Visuals 容器内的节点顺序与 Spine 渲染层级 100% 一致
	for slot_info in json.data["slots"]:
		var slot_name = slot_info["name"]
		var _c = c[slot_name] # 对应的骨骼下插槽节点
		for sk in json.data.get("skins", []):
			var skin_name = sk.get("name", "default")
			var skin_attachments = sk.get("attachments", {})
			if skin_attachments.has(slot_name):
				for i2 in skin_attachments[slot_name]:
					var a = skin_attachments[slot_name][i2]
					var att_type = a.get("type", "region")
					
					# 忽略非图形附件（碰撞框、裁切、路径等）
					if att_type in ["boundingbox", "clipping", "path", "point"]:
						continue
					
					# 如果是 linkedmesh，解析继承父网格
					if att_type == "linkedmesh":
						var parent_mesh_name = a.get("parent", i2)
						var parent_skin_name = a.get("skin", "")
						var parent_mesh = find_parent_mesh(json, skin_name, slot_name, parent_mesh_name, parent_skin_name)
						if not parent_mesh.is_empty():
							for p_key in ["uvs", "triangles", "vertices", "hull", "edges", "width", "height"]:
								if parent_mesh.has(p_key) and not a.has(p_key):
									a[p_key] = parent_mesh[p_key]
							att_type = "mesh"
						else:
							print("警告：未找到 linkedmesh 的父网格：", parent_mesh_name)

					var visual_node_name = skin_name + "__" + i2
					var remote_node_name = "Remote_" + skin_name + "__" + i2
					
					# 在插槽下创建 RemoteTransform2D 远程连接 Visuals 中的图片/网格
					var remote = RemoteTransform2D.new()
					remote.name = remote_node_name
					_c.add_child(remote)
					remote.owner = node_2d

					var region_info = find_atlas_region(图集数据, skin_name, slot_name, i2, a)
					var page_name = region_info.get("page", "")
					var _xy = region_info.get("xy", Vector2.ZERO)
					var _size = region_info.get("size", Vector2.ZERO)
					var _orig = region_info.get("orig", _size)
					var _offset = region_info.get("offset", Vector2.ZERO)
					
					var _item = null

					if att_type == "mesh":
						var _poly = Polygon2D.new()
						_item = _poly
						_poly.texture_offset = Vector2(_xy.x, _xy.y)
						_poly.set_meta("png_path", page_name + "_ExtResource")
						if 是否浏览 and 图集数据.get("pages", {}).has(page_name):
							_poly.texture = 图集数据["pages"][page_name].get("texture")
						
						_poly.name = visual_node_name
						visuals.add_child(_poly)
						_poly.owner = node_2d
						remote.remote_path = remote.get_path_to(_poly)
						
						var uvs: PackedVector2Array = []
						var _uvs = a.get("uvs", [])
						var _uvw = a.get("width", _size.x if _size.x > 0 else 100.0)
						var _uvh = a.get("height", _size.y if _size.y > 0 else 100.0)
						for _i in range(0, _uvs.size(), 2):
							uvs.append(Vector2(_uvs[_i] * _uvw, _uvs[_i+1] * _uvh))
						_poly.uv = uvs
						
						var _ver = a.get("vertices", [])
						var points: PackedVector2Array = []
						var bone_data_map = {}
						for bone in json.data.get("bones", []):
							bone_data_map[bone["name"]] = bone
						
						# 如果UV数据比顶点数据多，说明有权重信息
						if _uvs.size() < _ver.size():
							# 带权重的网格由 Skeleton2D 权重系统驱动，不更新 RemoteTransform 位置
							remote.update_position = false
							remote.update_rotation = false
							remote.update_scale = false

							var _weights = parse_weights(_ver)
							for _i_vertex_weights in _weights:
								var 最终坐标 = Vector2.ZERO
								for bone_weight_info in _i_vertex_weights:
									var bone_id_index = bone_weight_info["bone_id"]
									var bone_name = json.data["bones"][bone_id_index]["name"]
									var bone_world_matrix = calculate_bone_world_matrix(bone_name, bone_data_map)
									var local_offset_to_bone = Vector2(bone_weight_info["x"], bone_weight_info["y"])
									var transformed_point = bone_world_matrix * local_offset_to_bone
									最终坐标 += transformed_point * bone_weight_info["weight"]
								
								最终坐标.y *= -1
								points.append(最终坐标)
						else:
							# 无权重网格受骨骼 RemoteTransform 驱动
							remote.update_position = true
							remote.update_rotation = true
							remote.update_scale = true
							for _i in range(0, _ver.size(), 2):
								points.append(Vector2(_ver[_i], _ver[_i+1] * -1))

						_poly.polygon = points
						var hull_count = a.get("hull", 0)
						_poly.internal_vertex_count = max(0, int(_uvs.size() / 2) - hull_count)
						
						var trianles = []
						var _triangles = a.get("triangles", [])
						for _i in range(0, _triangles.size(), 3):
							if _i + 2 < _triangles.size():
								var _t = []
								_t.push_back(_triangles[_i])
								_t.push_back(_triangles[_i+1])
								_t.push_back(_triangles[_i+2])
								trianles.push_back(_t)
						_poly.polygons = trianles
						
						# 生成权重数据
						if _uvs.size() < _ver.size():
							_poly.skeleton = _poly.get_path_to(k)
							var _weights = parse_weights(_ver)
							var new_bones = []
							var _sn = 0
							for _i in s:
								var new_qz: PackedFloat32Array = []
								for _a in range(_poly.polygon.size()):
									var 权重 = 0.0
									if _a < _weights.size():
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
						
						_poly.visible = false
					else:
						# 默认作为图片 (region) 处理
						var _sprite = Sprite2D.new()
						_item = _sprite
						
						var tex = AtlasTexture.new()
						tex.region = Rect2(_xy.x, _xy.y, _size.x, _size.y)
						tex.margin = Rect2(_offset.x, _offset.y, _orig.x - _size.x, _orig.y - _size.y)
						if 是否浏览 and 图集数据.get("pages", {}).has(page_name):
							tex.atlas = 图集数据["pages"][page_name].get("texture")
						_sprite.texture = tex
						tex.set_meta("atlas_path", page_name + "_ExtResource")
						
						_sprite.name = visual_node_name
						visuals.add_child(_sprite)
						_sprite.owner = node_2d
						remote.remote_path = remote.get_path_to(_sprite)
						
						# 将图片在骨骼插槽中的局部偏移设置在 RemoteTransform2D 上
						var pos = Vector2.ZERO
						if a.has("x"):
							pos.x = a['x']
						if a.has("y"):
							pos.y = a['y'] * -1
						remote.position = pos
						
						if a.has("rotation"):
							remote.rotation_degrees = a['rotation'] * -1
						
						var sca = Vector2.ONE
						if a.has("scaleX"):
							sca.x = a['scaleX']
						if a.has("scaleY"):
							sca.y = a['scaleY']
						remote.scale = sca
						
						_sprite.visible = false
					
					# 材质与混合模式
					if _item:
						if slot_info.has("blend"):
							var _add = false
							if slot_info.has("attachment") and slot_info["attachment"] == i2:
								_add = true
							if slot_info['name'] == slot_name:
								_add = true
							if _add:
								if slot_info["blend"] == "additive":
									var mat = CanvasItemMaterial.new()
									mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
									_item.material = mat

		# 初始化插槽的默认切换名
		if slot_info.has("attachment"):
			_c.切换名 = slot_info["attachment"]
		else:
			_c.切换名 = ""
	return c


# 辅助函数：解析Spine曲线数据，返回[c1,c2,c3,c4]数组
func parse_spine_curve(data: Dictionary) -> Array:
	if not data.has("curve"):
		# 默认线性曲线 (linear)
		return [0.0, 0.0, 1.0, 1.0] 
	
	var curve = data["curve"]
	if str(curve) == "stepped":
		# 阶梯曲线 (stepped)
		# 用贝塞尔模拟一个几乎垂直上升然后水平前进的曲线
		return [100.0, 0.0, 1.0, 1.0]
	elif typeof(curve) == TYPE_ARRAY:
		# 已经是 [c1, c2, c3, c4] 格式
		return curve
	else: 
		# 单个数字格式
		var c1 = curve
		var c2 = data.get("c2", 0.0)
		var c3 = data.get("c3", 1.0)
		var c4 = data.get("c4", 1.0)
		return [c1, c2, c3, c4]


func 创建动画(json,s,_k,c):
	var animplay = AnimationPlayer.new()
	animplay.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	node_2d.add_child(animplay)
	animplay.owner = node_2d
	animplay.name = "AnimationPlayer"
	
	var al = AnimationLibrary.new()
	var lg_anim = json.data['animations']
	for i in lg_anim:
		var animation = Animation.new()
		var 动画名 = i
		var 预估时长 = 0
		if lg_anim[i].has("slots"):
			var 插槽动画数据 = lg_anim[i]["slots"]
			for 插槽名 in 插槽动画数据:
				if 插槽动画数据[插槽名].has("color"):
					var 颜色帧 = 插槽动画数据[插槽名]["color"]
					if 颜色帧.is_empty(): continue

					var 原始颜色 = c[插槽名].modulate
					
					# 关键区别 1: 必须为 r, g, b, a 四个通道分别创建轨道
					for rgba in ['r', 'g', 'b', 'a']:
						var 插槽径 =  str(node_2d.get_path_to(c[插槽名])) + ":modulate:" + rgba
						var track_index = animation.add_track(Animation.TYPE_BEZIER)
						animation.track_set_path(track_index, 插槽径)

						# -----------------------------------------------------------------
						# 步骤 1: 将Spine数据解析成一个干净的Keyframe列表
						# -----------------------------------------------------------------
						var clean_keys = []
						for frame_data in 颜色帧:
							var time = frame_data.get("time", 0.0)
							
							# 关键区别 2: 从 "color" hex 字符串中获取值
							var final_color = 原始颜色
							if frame_data.has("color"):
								# Godot 的 Color() 构造函数可以直接解析 "rrggbbaa" 格式的十六进制字符串
								final_color = Color(frame_data["color"])
							
							# 关键区别 3: 根据当前循环的通道 (r, g, b, a) 提取对应的浮点数值
							var value = final_color[rgba]
							
							var curve_params = parse_spine_curve(frame_data)
							
							clean_keys.append({
								"time": time,
								"value": value,
								"curve": curve_params
							})

						# -----------------------------------------------------------------
						# 步骤 2: 计算绝对控制柄并插入到Godot轨道中 (逻辑完全相同)
						# -----------------------------------------------------------------
						for _i in range(clean_keys.size()):
							var current_key = clean_keys[_i]
							var in_handle = Vector2.ZERO
							var out_handle = Vector2.ZERO

							if _i > 0:
								var prev_key = clean_keys[_i-1]
								var delta_time = current_key.time - prev_key.time
								var delta_value = current_key.value - prev_key.value
								
								var prev_curve = prev_key["curve"]
								var c3 = prev_curve[2]
								var c4 = prev_curve[3]
								
								in_handle.x = (c3 - 1.0) * delta_time
								in_handle.y = (c4 - 1.0) * delta_value

							if _i < clean_keys.size() - 1:
								var next_key = clean_keys[_i+1]
								var delta_time = next_key.time - current_key.time
								var delta_value = next_key.value - current_key.value
								
								var current_curve = current_key["curve"]
								var c1 = current_curve[0]
								var c2 = current_curve[1]

								out_handle.x = c1 * delta_time
								out_handle.y = c2 * delta_value
							
							animation.bezier_track_insert_key(
								track_index,
								current_key.time,
								current_key.value,
								in_handle,
								out_handle
							)
							if 预估时长<current_key.time:
								预估时长 = current_key.time
				
				if 插槽动画数据[插槽名].has("attachment"):
					var 切换帧 = 插槽动画数据[插槽名]["attachment"]
					
					var 插槽径 =  str(node_2d.get_path_to(c[插槽名])) + ":切换名"
					var track_index = animation.add_track(Animation.TYPE_VALUE)# 添加轨道
					animation.track_set_path(track_index, 插槽径)
					# 离散更新模式，保证只切换帧一次，而不是很多次
					animation.value_track_set_update_mode(track_index,Animation.UPDATE_DISCRETE)
					animation.track_set_interpolation_type(track_index,Animation.INTERPOLATION_NEAREST)
					animation.track_insert_key(track_index,0.0, c[插槽名].切换名)# 添加第一帧初始化
					
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
		
		# 导入顶点动画轨道（支持多皮肤）
		if lg_anim[i].has("deform"):
			var deform_skins_data = lg_anim[i]["deform"]
			var visuals_node = node_2d.get_node_or_null("Visuals")
			for deform_skin_name in deform_skins_data:
				var 顶点动画数据 = deform_skins_data[deform_skin_name]
				for 插槽名 in 顶点动画数据:
					for 网格名 in 顶点动画数据[插槽名]:
						var 顶点帧 = 顶点动画数据[插槽名][网格名]
						var target_visual_name = deform_skin_name + "__" + 网格名
						var _poly: Polygon2D = null
						if visuals_node:
							_poly = visuals_node.get_node_or_null(target_visual_name) as Polygon2D
							if not _poly:
								_poly = visuals_node.get_node_or_null(网格名) as Polygon2D
						if not _poly and c.has(插槽名):
							for child in c[插槽名].get_children():
								if child is RemoteTransform2D:
									var match_name = child.name.trim_prefix("Remote_").trim_prefix("Slot_")
									if match_name == target_visual_name or match_name.ends_with("__" + 网格名):
										_poly = child.get_node_or_null(child.remote_path) as Polygon2D
										if _poly: break
						if not _poly:
							continue
						
						var 顶点径 =  str(node_2d.get_path_to(_poly)) + ":polygon"
						var track_index = animation.add_track(Animation.TYPE_VALUE)# 添加轨道
						animation.track_set_path(track_index, 顶点径)
						for _vd in 顶点帧:
							var 延迟 = 0
							var _offset = 0
							var _vertices = _poly.polygon.duplicate()
							if _vd.has('time'):
								延迟 = _vd['time']
								if 预估时长<延迟:
									预估时长 = 延迟
							if _vd.has('offset'):
								_offset = _vd['offset']
							if _vd.has('vertices') and _poly.bones.size() == 0:# 说明这个网格无权重
								var _vds = _vd['vertices']# 拷贝顶点数组
								for _o in range(_offset):
									_vds.push_front(0)# 补全数组，spine的顶点数组不全
								if _vds.size()%2 == 1:# 如果是奇数，在末尾补0
									_vds.push_back(0)
								var _vn = 0
								for _i in range(0, _vds.size(), 2):# 把数组变成vector2数组
									_vertices[_vn] += Vector2(_vds[_i],_vds[_i+1]*-1)# 此时是vector相加
									_vn += 1
							if _vd.has('vertices') and _poly.bones.size() > 0:# 说明这个网格有权重
								var _vds = _vd['vertices']# 拷贝顶点数组
								if int(_offset)%2==1:# 如果是奇数前面加0
									_vds.push_front(0)
									_offset-=1# 说明缺少第一个点的x轴
								if _vds.size()%2==1:# 说明最后一个点缺少y轴
									_vds.push_back(0)
								
								# 查找对应皮肤下的权重网格顶点
								var 权重网格 = []
								for sk_find in json.data.get('skins', []):
									if sk_find.get('name', '') == deform_skin_name:
										var atts_find = sk_find.get('attachments', {})
										if atts_find.has(插槽名) and atts_find[插槽名].has(网格名):
											var att_obj = atts_find[插槽名][网格名]
											if att_obj.get("type", "") == "linkedmesh":
												var p_mesh = find_parent_mesh(json, deform_skin_name, 插槽名, att_obj.get("parent", 网格名), att_obj.get("skin", ""))
												权重网格 = p_mesh.get("vertices", [])
											else:
												权重网格 = att_obj.get("vertices", [])
											break
								if 权重网格.is_empty() and json.data.get('skins', []).size() > 0:
									var def_atts = json.data['skins'][0].get('attachments', {})
									if def_atts.has(插槽名) and def_atts[插槽名].has(网格名):
										var att_obj = def_atts[插槽名][网格名]
										if att_obj.get("type", "") == "linkedmesh":
											var p_mesh = find_parent_mesh(json, "default", 插槽名, att_obj.get("parent", 网格名), att_obj.get("skin", ""))
											权重网格 = p_mesh.get("vertices", [])
										else:
											权重网格 = def_atts[插槽名][网格名].get("vertices", [])
								
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
				var bone_node = s[骨名]
				# 查找与该骨骼关联的RemoteTransform2D节点
				var remote_node = bone_node.find_child("NoRotation", false) # false表示非递归查找
				# 默认情况下，动画目标是骨骼本身
				var position_target = bone_node
				var scale_target = bone_node
				# 旋转动画始终应用于骨骼本身
				var rotation_target = bone_node
				if remote_node:
					if not remote_node.旋转:
						rotation_target = remote_node
					if not remote_node.缩放:
						scale_target = remote_node
				
				if 骨骼动画数据[骨名].has("translate"):
					var 变换帧 = 骨骼动画数据[骨名]["translate"]
					if 变换帧.is_empty(): continue

					var 原始变换 = position_target.position
					
					# 分别为 x 和 y 轴创建轨道
					for xy in ['x', 'y']:
						var 骨路径 =  str(node_2d.get_path_to(position_target)) + ":position:" + xy
						var track_index = animation.add_track(Animation.TYPE_BEZIER)
						animation.track_set_path(track_index, 骨路径)

						# -----------------------------------------------------------------
						# 步骤 1: 将Spine数据解析成一个干净的Keyframe列表
						# -----------------------------------------------------------------
						var clean_keys = []

						for frame_data in 变换帧:
							var time = frame_data.get("time", 0.0)
							
							var offset = frame_data.get(xy, 0.0)
							if xy == 'y':
								offset *= -1 # Godot的Y轴是向下的

							var value = 原始变换[xy] + offset
							var curve_params = parse_spine_curve(frame_data)
							
							clean_keys.append({
								"time": time,
								"value": value,
								"curve": curve_params # 定义了从此帧到下一帧的曲线
							})

						# -----------------------------------------------------------------
						# 步骤 2: 计算绝对控制柄并插入到Godot轨道中
						# -----------------------------------------------------------------
						for _i in range(clean_keys.size()):
							var current_key = clean_keys[_i]
							var in_handle = Vector2.ZERO
							var out_handle = Vector2.ZERO

							# 计算 In-Handle (由前一帧的出射曲线决定)
							if _i > 0:
								var prev_key = clean_keys[_i-1]
								var delta_time = current_key.time - prev_key.time
								var delta_value = current_key.value - prev_key.value
								
								var prev_curve = prev_key["curve"]
								var c3 = prev_curve[2]
								var c4 = prev_curve[3]
								
								in_handle.x = (c3 - 1.0) * delta_time
								in_handle.y = (c4 - 1.0) * delta_value

							# 计算 Out-Handle (由此帧的出射曲线和下一帧的位置决定)
							if _i < clean_keys.size() - 1:
								var next_key = clean_keys[_i+1]
								var delta_time = next_key.time - current_key.time
								var delta_value = next_key.value - current_key.value
								
								var current_curve = current_key["curve"]
								var c1 = current_curve[0]
								var c2 = current_curve[1]

								out_handle.x = c1 * delta_time
								out_handle.y = c2 * delta_value
							
							# 插入最终计算好的关键帧
							animation.bezier_track_insert_key(
								track_index,
								current_key.time,
								current_key.value,
								in_handle,
								out_handle
							)
							if 预估时长<current_key.time:
								预估时长 = current_key.time
					
				if 骨骼动画数据[骨名].has("rotate"):
					var 旋转帧 = 骨骼动画数据[骨名]["rotate"]
					if 旋转帧.is_empty(): continue

					# 注意: 旋转动画始终应用于骨骼本身
					var 原始旋转值 = rotation_target.rotation_degrees
					
					# 关键区别 1: 轨道路径是 :rotation (使用弧度)，而不是 :rotation_degrees
					var 骨路径 =  str(node_2d.get_path_to(rotation_target)) + ":rotation"
					var track_index = animation.add_track(Animation.TYPE_BEZIER)
					animation.track_set_path(track_index, 骨路径)

					# -----------------------------------------------------------------
					# 步骤 1: 将Spine数据解析成一个干净的Keyframe列表 (单位: 度)
					# -----------------------------------------------------------------
					var clean_keys = []
					for frame_data in 旋转帧:
						var time = frame_data.get("time", 0.0)
						
						# Spine的角度是偏移量, 且方向与Godot相反
						var offset = frame_data.get("angle", 0.0) * -1.0
						var value = 原始旋转值 + offset
						
						var curve_params = parse_spine_curve(frame_data)
						
						clean_keys.append({ "time": time, "value": value, "curve": curve_params })

					# -----------------------------------------------------------------
					# 步骤 2: "解包"角度值以确保总是走最短路径
					# -----------------------------------------------------------------
					var unwrapped_keys = []
					if not clean_keys.is_empty():
						unwrapped_keys.append(clean_keys[0]) # 第一个key保持不变
						
						for _i in range(1, clean_keys.size()):
							var prev_key = unwrapped_keys[_i-1]
							var current_key = clean_keys[_i]
							
							var diff = current_key.value - prev_key.value
							# 将差值标准化到 -180 到 +180 之间
							diff = fposmod(diff + 180.0, 360.0) - 180.0
							
							var unwrapped_value = prev_key.value + diff
							
							unwrapped_keys.append({
								"time": current_key.time,
								"value": unwrapped_value, # 使用解包后的值
								"curve": current_key.curve
							})
					
					# -----------------------------------------------------------------
					# 步骤 3: 计算绝对控制柄并插入到Godot轨道中 (单位: 弧度)
					# -----------------------------------------------------------------
					for _i in range(unwrapped_keys.size()):
						var current_key = unwrapped_keys[_i]
						var in_handle = Vector2.ZERO
						var out_handle = Vector2.ZERO

						# 计算 In-Handle
						if _i > 0:
							var prev_key = unwrapped_keys[_i-1]
							var delta_time = current_key.time - prev_key.time
							# 关键区别 2: delta_value现在是解包后的差值, 并且要转为弧度
							var delta_value = deg_to_rad(current_key.value - prev_key.value)
							
							var prev_curve = prev_key["curve"]
							var c3 = prev_curve[2]
							var c4 = prev_curve[3]
							
							in_handle.x = (c3 - 1.0) * delta_time
							in_handle.y = (c4 - 1.0) * delta_value

						# 计算 Out-Handle
						if _i < unwrapped_keys.size() - 1:
							var next_key = unwrapped_keys[_i+1]
							var delta_time = next_key.time - current_key.time
							var delta_value = deg_to_rad(next_key.value - current_key.value)
							
							var current_curve = current_key["curve"]
							var c1 = current_curve[0]
							var c2 = current_curve[1]

							out_handle.x = c1 * delta_time
							out_handle.y = c2 * delta_value
						
						# 关键区别 3: 插入轨道的值和控制柄的Y值都必须是弧度
						animation.bezier_track_insert_key(
							track_index,
							current_key.time,
							deg_to_rad(current_key.value),
							in_handle,
							out_handle
						)
						if 预估时长<current_key.time:
							预估时长 = current_key.time
				
				if 骨骼动画数据[骨名].has("scale"):
					var 缩放帧 = 骨骼动画数据[骨名]["scale"]
					if 缩放帧.is_empty(): continue

					# 注意: 此处使用了您要求的 scale_target
					var 原始缩放 = scale_target.scale
					
					# 分别为 x 和 y 轴创建轨道
					for xy in ['x', 'y']:
						var 骨路径 =  str(node_2d.get_path_to(scale_target)) + ":scale:" + xy
						var track_index = animation.add_track(Animation.TYPE_BEZIER)
						animation.track_set_path(track_index, 骨路径)

						# -----------------------------------------------------------------
						# 步骤 1: 将Spine数据解析成一个干净的Keyframe列表
						# -----------------------------------------------------------------
						var clean_keys = []

						for frame_data in 缩放帧:
							var time = frame_data.get("time", 0.0)
							
							# 主要区别：
							# 1. scale的值是直接替换，而不是偏移量
							# 2. 如果帧数据中没有该轴的值，则使用原始缩放值
							# 3. Y轴不需要*-1
							var value = frame_data.get(xy, 原始缩放[xy])
							
							var curve_params = parse_spine_curve(frame_data)
							
							clean_keys.append({
								"time": time,
								"value": value,
								"curve": curve_params
							})

						# -----------------------------------------------------------------
						# 步骤 2: 计算绝对控制柄并插入到Godot轨道中
						# -----------------------------------------------------------------
						# 注意: 此处使用了您要求的循环变量 _i
						for _i in range(clean_keys.size()):
							var current_key = clean_keys[_i]
							var in_handle = Vector2.ZERO
							var out_handle = Vector2.ZERO

							# 计算 In-Handle (由前一帧的出射曲线决定)
							if _i > 0:
								var prev_key = clean_keys[_i-1]
								var delta_time = current_key.time - prev_key.time
								var delta_value = current_key.value - prev_key.value
								
								var prev_curve = prev_key["curve"]
								var c3 = prev_curve[2]
								var c4 = prev_curve[3]
								
								in_handle.x = (c3 - 1.0) * delta_time
								in_handle.y = (c4 - 1.0) * delta_value

							# 计算 Out-Handle (由此帧的出射曲线和下一帧的位置决定)
							if _i < clean_keys.size() - 1:
								var next_key = clean_keys[_i+1]
								var delta_time = next_key.time - current_key.time
								var delta_value = next_key.value - current_key.value
								
								var current_curve = current_key["curve"]
								var c1 = current_curve[0]
								var c2 = current_curve[1]

								out_handle.x = c1 * delta_time
								out_handle.y = c2 * delta_value
							
							# 插入最终计算好的关键帧
							animation.bezier_track_insert_key(
								track_index,
								current_key.time,
								current_key.value,
								in_handle,
								out_handle
							)
							if 预估时长<current_key.time:
								预估时长 = current_key.time
		
		animation.set_length(预估时长)
		
		# 检测动画名是否合法，不能包括“[]”
		动画名 = 动画名.replace("[","_")
		动画名 = 动画名.replace("]","_")
		动画名 = 动画名.replace("/","_")
		al.add_animation(动画名,animation)
		
	var anim_library_name = "animations"
	animplay.add_animation_library(anim_library_name,al)
	
	#region 创建默认初始化姿势
	# 创建默认初始化姿势
	var 全局库 = AnimationLibrary.new()
	animplay.add_animation_library("",全局库)
	var global_library = animplay.get_animation_library("")
	var RESET_anim = Animation.new()
	RESET_anim.set_length(0.001)
	global_library.add_animation("RESET", RESET_anim)
	# 初始化所有插槽
	for i in c:
		var 插槽径 =  str(node_2d.get_path_to(c[i])) + ":切换名"
		var track_index = RESET_anim.add_track(Animation.TYPE_VALUE)# 添加轨道
		RESET_anim.track_set_path(track_index, 插槽径)
		# 离散更新模式，保证只切换帧一次，而不是很多次
		RESET_anim.value_track_set_update_mode(track_index,Animation.UPDATE_DISCRETE)
		RESET_anim.track_set_interpolation_type(track_index,Animation.INTERPOLATION_NEAREST)
		var 切换名 = c[i].切换名
		RESET_anim.track_insert_key(track_index,0.0, 切换名)
		
		var 颜色通道 = {'r':c[i].modulate.r,'g':c[i].modulate.g,'b':c[i].modulate.b,'a':c[i].modulate.a}
		for rgba in 颜色通道:
			var 插槽颜色径 =  str(node_2d.get_path_to(c[i])) + ":modulate:"+rgba
			var track_index2 = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
			RESET_anim.track_set_path(track_index2, 插槽颜色径)
			RESET_anim.bezier_track_insert_key(track_index2,0.0, 颜色通道[rgba])
		
	# 初始化所有骨骼
	for i in s:
		var 位置通道 = {'x':s[i].position.x,'y':s[i].position.y}
		for xy in 位置通道:
			var 骨骼位置径 =  str(node_2d.get_path_to(s[i])) + ":position:"+xy
			var track_index = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
			RESET_anim.track_set_path(track_index, 骨骼位置径)
			RESET_anim.bezier_track_insert_key(track_index,0.0, 位置通道[xy])
		
		var 骨骼旋转径 =  str(node_2d.get_path_to(s[i])) + ":rotation"
		var track_index2 = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
		RESET_anim.track_set_path(track_index2, 骨骼旋转径)
		RESET_anim.bezier_track_insert_key(track_index2,0.0, s[i].rotation)
		#RESET_anim.value_track_set_update_mode(track_index2,Animation.UPDATE_DISCRETE)
		# 必须要跟上面所有动画的插值类型一样才不会警告
		#RESET_anim.track_set_interpolation_type(track_index2,Animation.INTERPOLATION_LINEAR_ANGLE)
		
		var 缩放通道 = {'x':s[i].scale.x,'y':s[i].scale.y}
		for xy in 缩放通道:
			var 骨骼缩放径 =  str(node_2d.get_path_to(s[i])) + ":scale:"+xy
			var track_index3 = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
			RESET_anim.track_set_path(track_index3, 骨骼缩放径)
			RESET_anim.bezier_track_insert_key(track_index3,0.0, 缩放通道[xy])
	
	# 初始化所有NoRotation
	for i in s:
		var remote_node = s[i].find_child("NoRotation", false) # false表示非递归查找
		if remote_node:
			var 旋转径 =  str(node_2d.get_path_to(remote_node)) + ":rotation"
			var track_index2 = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
			RESET_anim.track_set_path(track_index2, 旋转径)
			RESET_anim.bezier_track_insert_key(track_index2,0.0, remote_node.rotation)
			#RESET_anim.value_track_set_update_mode(track_index2,Animation.UPDATE_DISCRETE)
			# 必须要跟上面所有动画的插值类型一样才不会警告
			#RESET_anim.track_set_interpolation_type(track_index2,Animation.INTERPOLATION_LINEAR_ANGLE)
			
			var 缩放通道 = {'x':s[i].scale.x,'y':s[i].scale.y}
			for xy in 缩放通道:
				var 缩放径 =  str(node_2d.get_path_to(remote_node)) + ":scale:"+xy
				var track_index3 = RESET_anim.add_track(Animation.TYPE_BEZIER)# 添加轨道
				RESET_anim.track_set_path(track_index3, 缩放径)
				RESET_anim.bezier_track_insert_key(track_index3,0.0, 缩放通道[xy])
	#endregion
		
