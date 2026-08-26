@tool
class_name SpineToGodotSkinManager
extends Node

## 可用的皮肤列表
@export var available_skins: Array[String] = ["default"]:
	set(value):
		available_skins = value
		notify_property_list_changed()

## 当前激活的皮肤（使用私有变量防递归）
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
	if node.has_method("set_skin"):
		node.call("set_skin", skin_name)
	for child in node.get_children():
		if child != self:
			_update_slots_recursive(child, skin_name)
