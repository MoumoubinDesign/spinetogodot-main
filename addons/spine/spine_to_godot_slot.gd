@tool
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

	# 1. 寻找最匹配当前皮肤和切换名的 RemoteTransform2D 节点（支持 default 皮肤与前缀智能回退）
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

			# 匹配切换名（精确或去除路径前缀后匹配）
			if _switch_name != "" and (item_att == _switch_name or clean_item_att == clean_slot_att):
				if item_skin == _current_skin:
					best_match_remote = child
				elif item_skin == "default":
					fallback_match_remote = child
			
			# 记录当前皮肤及 default 皮肤下的第一个可用 remote
			if item_skin == _current_skin and skin_match_remote == null:
				skin_match_remote = child
			elif item_skin == "default" and default_remote == null:
				default_remote = child

	var chosen_remote = best_match_remote
	if chosen_remote == null:
		chosen_remote = fallback_match_remote
	if chosen_remote == null:
		chosen_remote = skin_match_remote if skin_match_remote != null else default_remote

	# 2. 更新所有子 RemoteTransform2D 所指向的 Visual 节点的可见性
	for child in children:
		if child is RemoteTransform2D:
			var target_node = child.get_node_or_null(child.remote_path)
			if target_node:
				target_node.visible = (child == chosen_remote)
