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
