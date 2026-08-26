@tool  # 必须保留 @tool，否则无法在编辑器内运行
class_name 插槽 
extends Node2D

@export var 切换名: String = "":
	set(value):
		切换名 = value
		# [核心修改] 只有在编辑器模式下，才执行消耗性能的节点遍历
		if Engine.is_editor_hint():
			_update_visibility()

func _ready():
	# [核心修改] 游戏运行时，直接禁用此脚本的所有处理，节省内存和CPU
	if not Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		return

func _update_visibility():
	# 你的原有逻辑保持不变
	var c = get_children()
	for i in c:
		if i is RemoteTransform2D:
			if i.name.begins_with("Slot_"):
				var target_node = i.get_node_or_null(i.remote_path)
				if target_node:
					var match_name = i.name.replace("Slot_", "")
					if match_name == 切换名:
						target_node.visible = true
					else:
						target_node.visible = false
