@tool
extends Node2D

## 1. 点击此开关进行节点搬家 (挂载在 Skeleton2D 专用版)
@export var 优化层级_开始搬家: bool = false:
	set(value):
		if value: _execute_structure_fix()
		优化层级_开始搬家 = false 

## 2. 搬家后，点击此开关修复动画报错
@export var 修复动画路径: bool = false:
	set(value):
		if value: _fix_animation_paths()
		修复动画路径 = false

# --- 功能 1: 结构优化 (搬家) ---
func _execute_structure_fix():
	print("--- 步骤1: 开始优化层级 (Skeleton2D 挂载版) ---")
	
	# [改动] 获取场景的根节点 (slime_spine)
	var root = get_parent()
	if not root:
		print("错误: Skeleton2D 没有父节点？请确保它在场景树中。")
		return

	# [改动] 在根节点下找 Visuals (与 Skeleton2D 平级)
	var visuals_node = root.get_node_or_null("Visuals")
	if not visuals_node:
		visuals_node = CanvasGroup.new()
		visuals_node.name = "Visuals"
		root.add_child(visuals_node) # 加到 root 下
		visuals_node.owner = get_tree().edited_scene_root
		print("创建 Visuals 容器 (在根节点下)")

	# 搜索 self (即 Skeleton2D) 内部的节点
	var nodes_to_process: Array[Node2D] = []
	_find_visual_nodes_recursive(self, nodes_to_process)
	
	var sort_list = []

	for visual_node in nodes_to_process:
		# 防止重复处理
		if visual_node.get_parent() == visuals_node:
			continue

		var original_parent = visual_node.get_parent()
		var current_z = visual_node.z_index
		
		# 叠加父级Z值
		if "z_index" in original_parent: 
			current_z += original_parent.z_index
			original_parent.z_index = 0 

		# 创建 RemoteTransform2D
		var remote = RemoteTransform2D.new()
		remote.name = "Remote_" + visual_node.name
		original_parent.add_child(remote)
		remote.owner = get_tree().edited_scene_root
		remote.transform = visual_node.transform # 保留偏移
		
		# 搬家
		visual_node.reparent(visuals_node)
		visual_node.owner = get_tree().edited_scene_root
		remote.remote_path = remote.get_path_to(visual_node)
		
		sort_list.append({"node": visual_node, "z": current_z})
		visual_node.z_index = 0
		print("已搬运: ", visual_node.name)

	# 排序
	sort_list.sort_custom(func(a, b): return a["z"] < b["z"])
	for i in range(sort_list.size()): 
		visuals_node.move_child(sort_list[i]["node"], i)
	
	print("--- 步骤1 完成 ---")

func _find_visual_nodes_recursive(node: Node, result_array: Array[Node2D]):
	for child in node.get_children():
		if child is Sprite2D or child is Polygon2D: 
			result_array.append(child)
		_find_visual_nodes_recursive(child, result_array)


# --- 功能 2: 动画修复 (改地址) ---
func _fix_animation_paths():
	print("--- 步骤2: 开始扫描并修复动画路径 ---")
	
	var root = get_parent()
	
	# [改动] 在根节点下找 AnimationPlayer
	var anim_player = root.find_child("AnimationPlayer", true, false)
	if not anim_player:
		print("错误: 在根节点下找不到 AnimationPlayer。")
		return

	# [改动] 在根节点下找 Visuals
	var visuals_node = root.get_node_or_null("Visuals")
	if not visuals_node:
		print("错误: 找不到 Visuals 节点，请先运行步骤1。")
		return

	var animation_list = anim_player.get_animation_list()
	var fix_count = 0

	for anim_name in animation_list:
		var anim = anim_player.get_animation(anim_name)
		for track_idx in range(anim.get_track_count()):
			var old_path = anim.track_get_path(track_idx)
			var string_path = str(old_path)
			
			if root.has_node(old_path): # 注意这里是用 root 来检查路径
				continue 
			
			# 提取节点名逻辑不变
			var path_without_property = string_path.split(":")[0]
			var node_name = path_without_property.split("/")[-1] 
			
			var target_node = visuals_node.find_child(node_name, false, false) 
			
			if target_node:
				var property_path = string_path.split(":")[-1]
				# 新路径需要是相对于 AnimationPlayer (通常是 Root) 的
				# 所以是 Visuals/节点名
				var new_path = NodePath(visuals_node.name + "/" + target_node.name + ":" + property_path)
				
				anim.track_set_path(track_idx, new_path)
				fix_count += 1
				print("修复轨道 [" + anim_name + "]: " + node_name + " -> 新位置")
	
	print("--- 步骤2 完成！共修复 " + str(fix_count) + " 条轨道 ---")
