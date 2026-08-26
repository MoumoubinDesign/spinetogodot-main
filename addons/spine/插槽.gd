@tool
class_name 插槽 
extends Node2D

@export var 切换名: String = "":
	set(value):
		切换名 = value
		_update_visibility()

func _ready():
	_update_visibility()

func _update_visibility():
	for child in get_children():
		if child is RemoteTransform2D:
			var target_node = child.get_node_or_null(child.remote_path)
			if target_node:
				var match_name = child.name.trim_prefix("Remote_").trim_prefix("Slot_")
				target_node.visible = (match_name == 切换名)
