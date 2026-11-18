extends Control

signal closed
signal link_requested(url: String)

const Language = preload("res://arcade_language.gd")
const PORTRAIT = preload("res://art/about_author.jpg")
const LOGO = preload("res://art/swarm_attack_logo.png")
const AUTHOR_NAME := "Franck Fornasari (Kraran)"
const AUTHOR_URL := "https://github.com/Kraran"
const REPOSITORY_URL := "https://github.com/Kraran/SwarmAttack"
const INK := Color("#080f1c")
const LINE := Color("#314765")
const TEXT := Color("#edf5ff")
const MUTED := Color("#9eafc6")
const ACCENT := Color("#70edcd")

var _language := "en"
var _choices: Array[BaseButton] = []
var _choice := 3
var _stick := Vector2i.ZERO
var _panel: PanelContainer
var _photo: Button
var _close: Button

func _init() -> void:
	visible = false
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_STOP

func present(logical_size: Vector2i, language: String) -> void:
	_language = language
	size = Vector2(logical_size)
	_stick = Vector2i.ZERO
	_choices.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	show()
	_build(logical_size.x < logical_size.y)
	_choice = 3
	_close.grab_focus()

func _text(source: String) -> String:
	return Language.text(source, _language)

func _box(color: Color, border: Color, margin := 0, rounded := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(rounded)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

func _label(parent: Node, text: String, points: int, color: Color, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _build(portrait: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.015,0.025,0.045,0.9)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = 512 if portrait else 860
	_panel.add_theme_stylebox_override("panel",_box(INK,LINE,22 if portrait else 26,10))
	center.add_child(_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",16)
	_panel.add_child(content)
	_label(content,_text("À propos").to_upper(),24,ACCENT)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation",18 if portrait else 26)
	content.add_child(layout)
	var photo_size := Vector2(140,199.5) if portrait else Vector2(200,285)
	var photo_box := Control.new()
	photo_box.custom_minimum_size = photo_size
	photo_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	layout.add_child(photo_box)
	var photo := TextureRect.new()
	photo.texture = PORTRAIT
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_box.add_child(photo)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.6,1.0])
	gradient.colors = PackedColorArray([Color(INK,0),INK])
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = gradient
	fade_texture.width = 64
	fade_texture.height = 4
	var fade := TextureRect.new()
	fade.texture = fade_texture
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_box.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_photo = Button.new()
	_photo.name = "AuthorPhoto"
	_photo.tooltip_text = AUTHOR_NAME + "\n" + AUTHOR_URL
	_photo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := _box(Color.TRANSPARENT,LINE,0,4)
	normal.draw_center = false
	var hover := _box(Color.TRANSPARENT,ACCENT,0,4)
	hover.draw_center = false
	_photo.add_theme_stylebox_override("normal",normal)
	for state in ["hover","pressed","focus"]:
		_photo.add_theme_stylebox_override(state,hover)
	_photo.pressed.connect(func(): link_requested.emit(AUTHOR_URL))
	photo_box.add_child(_photo)
	_photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choices.append(_photo)
	var info := VBoxContainer.new()
	info.custom_minimum_size.x = 310 if portrait else 540
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",10)
	layout.add_child(info)
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.custom_minimum_size = Vector2(160,90) if portrait else Vector2(200,112.5)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(logo)
	_label(info,_text("Défense orbitale en solo ou à deux, dix vagues et trois modules à assembler."),14 if portrait else 16,TEXT,true)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",6)
	info.add_child(grid)
	var engine := Engine.get_version_info()
	var rows := [
		["Version",str(ProjectSettings.get_setting("application/config/version",""))],
		["Création",AUTHOR_NAME],
		["Moteur","Godot %d.%d · GDScript" % [engine.major,engine.minor]],
	]
	for row in rows:
		_label(grid,_text(row[0]),14,MUTED)
		var value := _label(grid,row[1],14,TEXT,true)
		value.custom_minimum_size.x = 212 if portrait else 340
	_label(grid,_text("Projet"),14,MUTED)
	var repository := LinkButton.new()
	repository.text = "github.com/Kraran/SwarmAttack"
	repository.focus_mode = Control.FOCUS_NONE
	repository.add_theme_font_size_override("font_size",13 if portrait else 14)
	repository.add_theme_color_override("font_color",ACCENT)
	repository.tooltip_text = REPOSITORY_URL
	repository.pressed.connect(func(): link_requested.emit(REPOSITORY_URL))
	grid.add_child(repository)
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel",_box(Color("#0c2531"),LINE,10,5))
	info.add_child(note)
	_label(note,_text("Créé pour retrouver le plaisir de l’arcade."),13,MUTED,true)
	content.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",8)
	content.add_child(actions)
	var profile := _button(actions,"Profil GitHub")
	profile.pressed.connect(func(): link_requested.emit(AUTHOR_URL))
	var project := _button(actions,"Projet GitHub")
	project.pressed.connect(func(): link_requested.emit(REPOSITORY_URL))
	_close = _button(actions,"Fermer")
	_close.name = "AboutClose"
	_close.pressed.connect(func(): closed.emit())
	for index in _choices.size():
		_choices[index].focus_entered.connect(_select.bind(index))

func _button(parent: Node, source: String) -> Button:
	var button := Button.new()
	button.text = _text(source)
	button.custom_minimum_size.y = 40
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size",14)
	button.add_theme_color_override("font_color",TEXT)
	button.add_theme_stylebox_override("normal",_box(Color("#142239"),LINE,10,5))
	button.add_theme_stylebox_override("hover",_box(Color("#203850"),ACCENT,10,5))
	button.add_theme_stylebox_override("pressed",_box(Color("#29435c"),ACCENT,10,5))
	button.add_theme_stylebox_override("focus",_box(Color.TRANSPARENT,ACCENT,0,5))
	parent.add_child(button)
	_choices.append(button)
	return button

func _select(index: int) -> void:
	_choice = index

func handle_input(event: InputEvent) -> bool:
	var direction := Vector2i.ZERO
	var accept := false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			closed.emit()
			return true
		accept = event.keycode in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]
		direction = Vector2i(int(event.keycode == KEY_RIGHT)-int(event.keycode == KEY_LEFT),int(event.keycode == KEY_DOWN)-int(event.keycode == KEY_UP))
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_B,JOY_BUTTON_START]:
			closed.emit()
			return true
		accept = event.button_index == JOY_BUTTON_A
		direction = Vector2i(int(event.button_index == JOY_BUTTON_DPAD_RIGHT)-int(event.button_index == JOY_BUTTON_DPAD_LEFT),int(event.button_index == JOY_BUTTON_DPAD_DOWN)-int(event.button_index == JOY_BUTTON_DPAD_UP))
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
		var axis := int(event.axis == JOY_AXIS_LEFT_Y)
		if absf(event.axis_value) < 0.4:
			_stick[axis] = 0
		elif absf(event.axis_value) >= 0.65 and int(signf(event.axis_value)) != _stick[axis]:
			_stick[axis] = int(signf(event.axis_value))
			direction[axis] = _stick[axis]
	if accept:
		_choices[_choice].pressed.emit()
		return true
	if direction != Vector2i.ZERO:
		if direction.y != 0:
			_choice = 0 if direction.y < 0 else 1
		else:
			_choice = 1 if _choice == 0 else 1+posmod(_choice-1+direction.x,3)
		_choices[_choice].grab_focus()
		return true
	return false
