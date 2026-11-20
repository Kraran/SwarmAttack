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
var _skin = null
var _offset := Vector2.ZERO
var _ink := INK
var _line := LINE
var _text_color := TEXT
var _muted := MUTED
var _accent := ACCENT
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

# skin: the interface skin (res://ui/skin.gd), or null for the neutral look.
# offset: canvas shift used to centre the game, so the veil covers wide screens.
func present(logical_size: Vector2i, language: String, skin = null, offset := Vector2.ZERO) -> void:
	_language = language
	_skin = skin
	_offset = offset
	if skin != null:
		_ink = skin.c("panel")
		_ink.a = 1.0
		_line = skin.c("panel_border")
		_text_color = skin.c("text")
		_muted = skin.c("muted")
		_accent = skin.c("accent")
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

func _label(parent: Node, text: String, points: int, color: Color, wrap := false, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	if _skin != null:
		font = _skin.detail_font if font == null else font
		points = _skin.body_size(points * 1.45)
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size",points)
	label.add_theme_color_override("font_color",color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _build(portrait: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.015,0.025,0.045,0.9) if _skin == null else Color(_skin.c("backdrop_edge"), 0.72)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = -_offset.x
	dim.offset_right = _offset.x
	dim.offset_top = -_offset.y
	dim.offset_bottom = _offset.y
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = 512 if portrait else 860
	var frame := _box(_ink,_line,22 if portrait else 26,10)
	if _skin != null:
		frame.set_border_width_all(3)
		frame.set_corner_radius_all(_skin.radius)
		frame.shadow_color = _skin.c("shadow")
		frame.shadow_offset = Vector2.ONE * _skin.shadow_offset * 2.0
		frame.shadow_size = 1 if _skin.shadow_offset > 0.0 else 0
	_panel.add_theme_stylebox_override("panel",frame)
	center.add_child(_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",16)
	_panel.add_child(content)
	var heading := _label(content,_text("À propos").to_upper(),24,_accent,false,null if _skin == null else _skin.title_font)
	if _skin != null:
		heading.add_theme_font_size_override("font_size", _skin.body_size(56))
		heading.add_theme_color_override("font_color", _skin.c("title"))
		heading.add_theme_color_override("font_shadow_color", _skin.c("title_shadow"))
		heading.add_theme_constant_override("shadow_offset_x", int(_skin.shadow_offset * 0.8))
		heading.add_theme_constant_override("shadow_offset_y", int(_skin.shadow_offset * 0.8))
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
	gradient.colors = PackedColorArray([Color(_ink,0),_ink])
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
	var normal := _box(Color.TRANSPARENT,_line,0,4)
	normal.draw_center = false
	var hover := _box(Color.TRANSPARENT,_accent,0,4)
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
	_label(info,_text("Défense orbitale en solo ou à deux, dix vagues et trois modules à assembler."),14 if portrait else 16,_text_color,true,null if _skin == null else _skin.body_font)
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
		_label(grid,_text(row[0]),14,_muted)
		var value := _label(grid,row[1],14,_text_color,true)
		value.custom_minimum_size.x = 212 if portrait else 340
	_label(grid,_text("Projet"),14,_muted)
	var repository := LinkButton.new()
	repository.text = "github.com/Kraran/SwarmAttack"
	repository.focus_mode = Control.FOCUS_NONE
	repository.add_theme_font_size_override("font_size",13 if portrait else 14)
	if _skin != null:
		repository.add_theme_font_override("font", _skin.body_font)
		repository.add_theme_font_size_override("font_size", _skin.body_size(22))
	repository.add_theme_color_override("font_color",_accent)
	repository.tooltip_text = REPOSITORY_URL
	repository.pressed.connect(func(): link_requested.emit(REPOSITORY_URL))
	grid.add_child(repository)
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel",_box(Color("#0c2531") if _skin == null else _skin.c("button_bottom"),_line,10,5 if _skin == null else _skin.radius))
	info.add_child(note)
	_label(note,_text("Créé pour retrouver le plaisir de l’arcade."),13,_muted,true)
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
	button.add_theme_color_override("font_color",_text_color)
	if _skin != null:
		_skin_button(button)
		parent.add_child(button)
		_choices.append(button)
		return button
	button.add_theme_stylebox_override("normal",_box(Color("#142239"),_line,10,5))
	button.add_theme_stylebox_override("hover",_box(Color("#203850"),_accent,10,5))
	button.add_theme_stylebox_override("pressed",_box(Color("#29435c"),_accent,10,5))
	button.add_theme_stylebox_override("focus",_box(Color.TRANSPARENT,_accent,0,5))
	parent.add_child(button)
	_choices.append(button)
	return button

# Slanted skin buttons; keyboard / gamepad focus uses the bright focus style.
func _skin_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := _box(fill, border, 12, _skin.radius)
	style.set_border_width_all(width)
	style.skew = Vector2(_skin.skew * 0.5, 0)
	style.shadow_color = _skin.c("shadow")
	style.shadow_offset = Vector2.ONE * _skin.shadow_offset
	style.shadow_size = 1 if _skin.shadow_offset > 0.0 else 0
	return style


func _skin_button(button: Button) -> void:
	button.custom_minimum_size.y = 52
	button.text = _skin.caps(button.text)
	button.add_theme_font_override("font", _skin.body_font)
	button.add_theme_font_size_override("font_size", _skin.body_size(30))
	button.add_theme_color_override("font_color", _skin.c("button_text"))
	button.add_theme_color_override("font_hover_color", _skin.c("text"))
	for state in ["font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, _skin.c("focus_text"))
	button.add_theme_stylebox_override("normal", _skin_style(_skin.c("button_top"), _skin.c("button_border"), 2))
	button.add_theme_stylebox_override("hover", _skin_style(_skin.c("button_top"), _skin.c("hover_border"), 2))
	button.add_theme_stylebox_override("pressed", _skin_style(_skin.c("focus_bottom"), _skin.c("focus_border"), 3))
	button.add_theme_stylebox_override("focus", _skin_style(_skin.c("focus_mid"), _skin.c("focus_border"), 3))


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
