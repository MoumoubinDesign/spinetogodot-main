extends Control


@onready var spine_json: Node = $SpineJson

const CONFIG_PATH = "user://settings.cfg"
var last_addon_install_dir: String = ""


func _ready() -> void:
	get_window().files_dropped.connect(_on_files_dropped)
	load_config()


func save_config() -> void:
	var config = ConfigFile.new()
	config.set_value("paths", "json_path", %JsonPath.text)
	config.set_value("paths", "atlas_path", %AtlasPath.text)
	config.set_value("paths", "res_path", %ResPath.text)
	config.set_value("paths", "return_path", %ReturnPath.text)
	config.set_value("paths", "batch_path", %"LineEdit_批量路径".text)
	config.set_value("paths", "last_addon_install_dir", last_addon_install_dir)
	config.save(CONFIG_PATH)


func load_config() -> void:
	var config = ConfigFile.new()
	var err = config.load(CONFIG_PATH)
	if err == OK:
		%JsonPath.text = config.get_value("paths", "json_path", %JsonPath.text)
		%AtlasPath.text = config.get_value("paths", "atlas_path", %AtlasPath.text)
		%ResPath.text = config.get_value("paths", "res_path", %ResPath.text)
		%ReturnPath.text = config.get_value("paths", "return_path", %ReturnPath.text)
		%"LineEdit_批量路径".text = config.get_value("paths", "batch_path", %"LineEdit_批量路径".text)
		last_addon_install_dir = config.get_value("paths", "last_addon_install_dir", "")


func _show_dialog(title: String, message: String) -> void:
	var dlg = AcceptDialog.new()
	add_child(dlg)
	dlg.title = title
	dlg.dialog_text = message
	dlg.popup_centered(Vector2i(480, 180))
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())


func _on_button_2_pressed() -> void:
	# json目录按钮
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.json")
	if %JsonPath.text != "":
		dialog.current_path = %JsonPath.text
	dialog.popup(Rect2i(200, 200, 600, 450))
	dialog.connect("file_selected", on_选择路径_file_selected)
	dialog.set_title("选择Json文件")


func on_选择路径_file_selected(path: String):
	%JsonPath.text = path
	var base = path.get_basename()
	if %AtlasPath.text == "" or not FileAccess.file_exists(%AtlasPath.text):
		var atlas_guess = base + ".atlas"
		if FileAccess.file_exists(atlas_guess):
			%AtlasPath.text = atlas_guess
	if %ReturnPath.text == "":
		%ReturnPath.text = base + ".tscn"
	save_config()


func _on_选择atlas_pressed() -> void:
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.atlas")
	if %AtlasPath.text != "":
		dialog.current_path = %AtlasPath.text
	elif %JsonPath.text != "":
		dialog.current_dir = %JsonPath.text.get_base_dir()
	dialog.popup(Rect2i(200, 200, 600, 450))
	dialog.connect("file_selected", on_选择路径atlas_file_selected)
	dialog.set_title("选择atlas图集文件")


func on_选择路径atlas_file_selected(path: String):
	%AtlasPath.text = path
	if %ReturnPath.text == "":
		%ReturnPath.text = path.get_basename() + ".tscn"
	save_config()


func _on_选择输出_pressed() -> void:
	# 保存文件目录按钮
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.add_filter("*.tscn")
	if %ReturnPath.text != "":
		dialog.current_path = %ReturnPath.text
	elif %JsonPath.text != "":
		dialog.current_dir = %JsonPath.text.get_base_dir()
	dialog.popup(Rect2i(200, 200, 600, 450))
	dialog.connect("file_selected", on_选择输出_file_selected)
	dialog.set_title("保存文件")


func on_选择输出_file_selected(path: String):
	%ReturnPath.text = path
	save_config()


func _on_button_pressed() -> void:
	# 保存文件目录按钮
	save_config()
	spine_json.res图像路径 = %ResPath.text
	spine_json.atlas路径 = %AtlasPath.text
	spine_json.保存文件(%JsonPath.text, %ReturnPath.text)


func _on_button_3_pressed() -> void:
	var dialog = FileDialog.new()
	add_child(dialog)
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	if last_addon_install_dir != "":
		dialog.current_dir = last_addon_install_dir
	elif %ReturnPath.text != "":
		dialog.current_dir = %ReturnPath.text.get_base_dir()
	dialog.popup(Rect2i(200, 200, 600, 450))
	dialog.connect("dir_selected", on_安装脚本_dir_selected)
	dialog.set_title("定位到所需工程根目录")


func on_安装脚本_dir_selected(path: String):
	last_addon_install_dir = path
	save_config()
	
	var dest_addons_dir = path
	var norm_path = path.replace("\\", "/")
	if not norm_path.ends_with("/addons/spine") and not norm_path.ends_with("/addons/spine/"):
		dest_addons_dir = path.path_join("addons/spine")
	
	if not DirAccess.dir_exists_absolute(dest_addons_dir):
		var err = DirAccess.make_dir_recursive_absolute(dest_addons_dir)
		if err != OK and not DirAccess.dir_exists_absolute(dest_addons_dir):
			_show_dialog("安装失败", "无法创建目标插件目录，请检查路径权限：\n" + dest_addons_dir)
			return
	
	var embedded_files = AddonsTemplates.get_files()
	var installed_count = 0
	
	for file_name in embedded_files:
		var dst_path = dest_addons_dir.path_join(file_name)
		var file_text = ""
		
		# 1. 优先尝试从本地源文件读取
		var src_path = "res://addons/spine/".path_join(file_name)
		if FileAccess.file_exists(src_path):
			var src_file = FileAccess.open(src_path, FileAccess.READ)
			if src_file:
				file_text = src_file.get_as_text()
				src_file.close()
		
		# 2. 如果导出成独立可执行程序后无法以纯文本读取 res://（Godot 编译导出特性），回退使用内置源码模板
		if file_text == "":
			file_text = embedded_files[file_name]
		
		var dst_file = FileAccess.open(dst_path, FileAccess.WRITE)
		if dst_file:
			dst_file.store_string(file_text)
			dst_file.flush()
			dst_file.close()
			installed_count += 1
			print("已安装插件文件: " + dst_path)
		else:
			print("写入失败: ", dst_path, " 错误码: ", FileAccess.get_open_error())
	
	if installed_count > 0:
		_show_dialog("安装成功", "插槽与插件脚本已成功安装/更新！\n共写入 %d 个文件至：\n%s" % [installed_count, dest_addons_dir])
	else:
		_show_dialog("安装失败", "未能写入插件文件，请检查目标目录权限。")


func _on_批量转换_pressed() -> void:
	save_config()
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
				var json路径 = path.path_join(file_name).path_join(file_name + ".json")
				spine_json.res图像路径 = "res://" + file_name + "/"
				spine_json.atlas路径 = path.path_join(file_name).path_join(file_name + ".atlas")
				var 导出路径 = path.path_join(file_name).path_join(file_name + ".tscn")
				spine_json.保存文件(json路径, 导出路径)
				print("已完成：" + str(n))
				n += 1
			else:
				print("发现文件" + file_name)
			file_name = dir.get_next()
	else:
		print("尝试访问路径时出错。")


func _on_预览_pressed() -> void:
	save_config()
	spine_json.res图像路径 = %ResPath.text
	spine_json.atlas路径 = %AtlasPath.text
	Global.根节点 = spine_json.预览文件(%JsonPath.text)
	get_tree().get_root().gui_embed_subwindows = false
	var w = preload("res://Spine编辑器/编辑器窗口.tscn").instantiate()
	w.gui_embed_subwindows = false
	add_child(w)


func _on_files_dropped(files):
	for i in files:
		var path: String = i
		if path.get_extension() == "json":
			%JsonPath.text = path
		if path.get_extension() == "atlas":
			%AtlasPath.text = path
			%ReturnPath.text = path.get_basename() + ".tscn"
	save_config()
	print(files)
