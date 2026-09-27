extends Node2D

# Sky Golf rhythm prototype.
# Godot 4.7.x / GDScript / single-threaded Web compatible.

enum GameState { TITLE, PRACTICE, PLAYING, RESULT }

const VIEW := Vector2(720.0, 1280.0)
const BPM := 124.0
const BEAT_SEC := 60.0 / BPM
const TRACK_BEATS := 96.0
const PERFECT_WINDOW := 0.055
const GREAT_WINDOW := 0.100
const GOOD_WINDOW := 0.165
const MISS_WINDOW := 0.190

var state := GameState.TITLE
var music: AudioStreamPlayer
var output_latency := 0.0
var last_song_time := 0.0
var input_offset_ms := 0.0
var events: Array = []
var fake_beats := [35.0, 57.0]
var fake_triggered := [false, false]
var finished := false

var world: Node2D
var bg: Sprite2D
var character: Sprite2D
var fake_bird: Sprite2D
var incoming_ball: Polygon2D
var shot_ball: Polygon2D
var character_base_scale := Vector2(0.64, 0.64)
var character_base_pos := Vector2(215.0, 900.0)
var shot_busy := false
var shot_anim_start := Vector2.ZERO
var shot_anim_end := Vector2.ZERO
var shot_anim_quality := 0
var miss_anim_start := Vector2.ZERO
var miss_anim_end := Vector2.ZERO

var fog_layer: CanvasLayer
var fog: ColorRect
var tint: ColorRect
var ui_layer: CanvasLayer
var title_panel: Control
var practice_panel: Control
var result_panel: Control
var section_label: Label
var status_label: Label
var offset_label: Label
var offset_slider: HSlider
var result_title: Label
var result_body: Label

var practice_step := 0
var practice_target_wall := 0.0
var practice_active := false
var practice_ready_to_start := false

var perfect_count := 0
var great_count := 0
var good_count := 0
var miss_count := 0
var panic_swings := 0
var early_count := 0
var late_count := 0
var current_section := -1

func _ready() -> void:
    output_latency = AudioServer.get_output_latency()
    _load_settings()
    _build_world()
    _build_ui()
    _show_title()

func _build_world() -> void:
    world = Node2D.new()
    world.name = "World"
    add_child(world)

    bg = Sprite2D.new()
    bg.texture = load("res://assets/backgrounds/sky_golf.png")
    bg.position = VIEW * 0.5
    var bg_size := bg.texture.get_size()
    var cover := max(VIEW.x / bg_size.x, VIEW.y / bg_size.y)
    bg.scale = Vector2.ONE * cover
    world.add_child(bg)

    var shadow := _make_circle(95.0, Color(0.10, 0.24, 0.30, 0.18))
    shadow.position = Vector2(220.0, 1080.0)
    shadow.scale = Vector2(1.25, 0.28)
    world.add_child(shadow)

    character = Sprite2D.new()
    character.texture = load("res://assets/characters/sora_pip.png")
    character.position = character_base_pos
    character.scale = character_base_scale
    world.add_child(character)

    fake_bird = Sprite2D.new()
    fake_bird.texture = load("res://assets/characters/pip.png")
    fake_bird.position = Vector2(-180.0, 360.0)
    fake_bird.scale = Vector2(0.50, 0.50)
    fake_bird.visible = false
    world.add_child(fake_bird)

    incoming_ball = _make_circle(20.0, Color("fffaf0"))
    incoming_ball.visible = false
    world.add_child(incoming_ball)

    shot_ball = _make_circle(18.0, Color.WHITE)
    shot_ball.visible = false
    world.add_child(shot_ball)

    fog_layer = CanvasLayer.new()
    fog_layer.layer = 3
    add_child(fog_layer)
    fog = ColorRect.new()
    fog.position = Vector2.ZERO
    fog.size = VIEW
    fog.color = Color(0.93, 0.98, 1.0, 0.0)
    fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fog_layer.add_child(fog)
    tint = ColorRect.new()
    tint.position = Vector2.ZERO
    tint.size = VIEW
    tint.color = Color(1.0, 0.72, 0.24, 0.0)
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fog_layer.add_child(tint)

    music = AudioStreamPlayer.new()
    music.name = "Music"
    music.stream = load("res://assets/audio/sky_golf_theme.wav")
    add_child(music)

func _build_ui() -> void:
    ui_layer = CanvasLayer.new()
    ui_layer.layer = 10
    add_child(ui_layer)

    section_label = _make_label("", 34, Vector2(60, 95), Vector2(600, 72))
    section_label.modulate.a = 0.0
    ui_layer.add_child(section_label)

    status_label = _make_label("", 28, Vector2(80, 1030), Vector2(560, 90))
    status_label.modulate.a = 0.0
    ui_layer.add_child(status_label)

    title_panel = Control.new()
    title_panel.position = Vector2.ZERO
    title_panel.size = VIEW
    ui_layer.add_child(title_panel)

    var title_back := ColorRect.new()
    title_back.position = Vector2(35, 80)
    title_back.size = Vector2(650, 1080)
    title_back.color = Color(1.0, 1.0, 1.0, 0.88)
    title_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_panel.add_child(title_back)

    var title := _make_label("SKY GOLF", 64, Vector2(70, 145), Vector2(580, 90))
    title.add_theme_color_override("font_color", Color("23445d"))
    title_panel.add_child(title)
    var subtitle := _make_label("そらのリズムで ナイスショット！", 26, Vector2(70, 238), Vector2(580, 50))
    subtitle.add_theme_color_override("font_color", Color("396b78"))
    title_panel.add_child(subtitle)

    var hero := TextureRect.new()
    hero.texture = load("res://assets/characters/sora_pip.png")
    hero.position = Vector2(145, 310)
    hero.size = Vector2(430, 430)
    hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
    title_panel.add_child(hero)

    var practice_button := _make_button("れんしゅう", Vector2(105, 785), Vector2(240, 84), Color("65c7de"))
    practice_button.pressed.connect(_on_practice_pressed)
    title_panel.add_child(practice_button)
    var start_button := _make_button("本番スタート", Vector2(375, 785), Vector2(240, 84), Color("ffd45c"))
    start_button.pressed.connect(_on_start_pressed)
    title_panel.add_child(start_button)

    var adjust := _make_label("タイミング補正", 22, Vector2(105, 900), Vector2(220, 42))
    adjust.add_theme_color_override("font_color", Color("35566b"))
    title_panel.add_child(adjust)
    offset_slider = HSlider.new()
    offset_slider.position = Vector2(105, 950)
    offset_slider.size = Vector2(510, 38)
    offset_slider.min_value = -150.0
    offset_slider.max_value = 150.0
    offset_slider.step = 5.0
    offset_slider.value = input_offset_ms
    offset_slider.value_changed.connect(_on_offset_changed)
    title_panel.add_child(offset_slider)
    offset_label = _make_label("", 20, Vector2(220, 995), Vector2(280, 40))
    offset_label.add_theme_color_override("font_color", Color("35566b"))
    title_panel.add_child(offset_label)
    _update_offset_label()

    var tip := _make_label("画面タップ / Space で打つ\n白い球=2音のあと　金の球=4音のあと", 22, Vector2(90, 1050), Vector2(540, 78))
    tip.add_theme_color_override("font_color", Color("456b73"))
    title_panel.add_child(tip)

    practice_panel = Control.new()
    practice_panel.position = Vector2.ZERO
    practice_panel.size = VIEW
    practice_panel.visible = false
    ui_layer.add_child(practice_panel)
    var practice_card := ColorRect.new()
    practice_card.position = Vector2(50, 120)
    practice_card.size = Vector2(620, 1040)
    practice_card.color = Color(1.0, 1.0, 1.0, 0.90)
    practice_panel.add_child(practice_card)
    var practice_title := _make_label("れんしゅう", 48, Vector2(80, 180), Vector2(560, 70))
    practice_title.add_theme_color_override("font_color", Color("23445d"))
    practice_panel.add_child(practice_title)
    var practice_text := _make_label("", 30, Vector2(90, 300), Vector2(540, 250))
    practice_text.name = "PracticeText"
    practice_text.add_theme_color_override("font_color", Color("35566b"))
    practice_panel.add_child(practice_text)
    var back_button := _make_button("タイトルへ", Vector2(220, 1000), Vector2(280, 80), Color("d7e9ef"))
    back_button.pressed.connect(_show_title)
    practice_panel.add_child(back_button)

    result_panel = Control.new()
    result_panel.position = Vector2.ZERO
    result_panel.size = VIEW
    result_panel.visible = false
    ui_layer.add_child(result_panel)
    var result_card := ColorRect.new()
    result_card.position = Vector2(45, 120)
    result_card.size = Vector2(630, 1040)
    result_card.color = Color(1.0, 1.0, 1.0, 0.94)
    result_panel.add_child(result_card)
    result_title = _make_label("", 58, Vector2(80, 200), Vector2(560, 90))
    result_title.add_theme_color_override("font_color", Color("23445d"))
    result_panel.add_child(result_title)
    result_body = _make_label("", 26, Vector2(90, 330), Vector2(540, 420))
    result_body.add_theme_color_override("font_color", Color("35566b"))
    result_panel.add_child(result_body)
    var retry := _make_button("もう一回", Vector2(100, 900), Vector2(240, 84), Color("ffd45c"))
    retry.pressed.connect(_on_start_pressed)
    result_panel.add_child(retry)
    var to_title := _make_button("タイトル", Vector2(380, 900), Vector2(240, 84), Color("d7e9ef"))
    to_title.pressed.connect(_show_title)
    result_panel.add_child(to_title)

func _make_label(text: String, font_size: int, pos: Vector2, size: Vector2) -> Label:
    var label := Label.new()
    label.text = text
    label.position = pos
    label.size = size
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color.WHITE)
    label.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.16, 0.90))
    label.add_theme_constant_override("outline_size", 6)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _make_button(text: String, pos: Vector2, size: Vector2, color: Color) -> Button:
    var button := Button.new()
    button.text = text
    button.position = pos
    button.size = size
    button.add_theme_font_size_override("font_size", 26)
    button.add_theme_color_override("font_color", Color("243843"))
    var normal := StyleBoxFlat.new()
    normal.bg_color = color
    normal.corner_radius_top_left = 24
    normal.corner_radius_top_right = 24
    normal.corner_radius_bottom_left = 24
    normal.corner_radius_bottom_right = 24
    normal.shadow_color = Color(0.0, 0.0, 0.0, 0.15)
    normal.shadow_size = 6
    var hover := normal.duplicate()
    hover.bg_color = color.lightened(0.10)
    var pressed := normal.duplicate()
    pressed.bg_color = color.darkened(0.08)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    return button

func _make_circle(radius: float, color: Color) -> Polygon2D:
    var node := Polygon2D.new()
    var points := PackedVector2Array()
    for i in range(28):
        var a := TAU * float(i) / 28.0
        points.append(Vector2(cos(a), sin(a)) * radius)
    node.polygon = points
    node.color = color
    return node

func _show_title() -> void:
    state = GameState.TITLE
    music.stop()
    incoming_ball.visible = false
    shot_ball.visible = false
    practice_panel.visible = false
    result_panel.visible = false
    title_panel.visible = true
    fog.color.a = 0.0
    tint.color.a = 0.0
    character.position = character_base_pos
    character.scale = character_base_scale
    character.rotation = 0.0
    _hide_status()

func _on_practice_pressed() -> void:
    title_panel.visible = false
    result_panel.visible = false
    practice_panel.visible = true
    state = GameState.PRACTICE
    practice_step = 0
    practice_active = false
    practice_ready_to_start = false
    _set_practice_text("白いボールは\n『ピン・ポン』の次でタップ！")
    _practice_begin_step()

func _practice_begin_step() -> void:
    if state != GameState.PRACTICE:
        return
    practice_active = false
    incoming_ball.visible = false
    if practice_step == 0:
        _set_practice_text("白いボール\n2つの音を聞いたら、その次でタップ")
        await get_tree().create_timer(0.65).timeout
        if state != GameState.PRACTICE:
            return
        _play_sfx("res://assets/audio/cue_normal.wav")
        practice_target_wall = _wall_time() + 2.0 * BEAT_SEC
        practice_active = true
        _animate_practice_ball(2.0 * BEAT_SEC, false)
    elif practice_step == 1:
        _set_practice_text("金のボール\n4つの上がる音を聞いて、その次でタップ")
        await get_tree().create_timer(0.65).timeout
        if state != GameState.PRACTICE:
            return
        _play_sfx("res://assets/audio/cue_special.wav")
        practice_target_wall = _wall_time() + 4.0 * BEAT_SEC
        practice_active = true
        _animate_practice_ball(4.0 * BEAT_SEC, true)
    else:
        _set_practice_text("小鳥の声はフェイク。\n音が鳴っても打たない！")
        fake_bird.visible = true
        fake_bird.position = Vector2(-120, 430)
        _play_sfx("res://assets/audio/bird.wav")
        var tw := create_tween()
        tw.tween_property(fake_bird, "position", Vector2(840, 350), 1.6).set_trans(Tween.TRANS_SINE)
        tw.finished.connect(func(): fake_bird.visible = false)
        await get_tree().create_timer(2.0).timeout
        if state != GameState.PRACTICE:
            return
        practice_ready_to_start = true
        _set_practice_text("OK！\n次のタップで本番スタート")

func _animate_practice_ball(duration: float, special: bool) -> void:
    incoming_ball.visible = true
    incoming_ball.color = Color("ffd85c") if special else Color("fffaf0")
    incoming_ball.position = Vector2(780, 800 if special else 845)
    var tw := create_tween()
    tw.tween_property(incoming_ball, "position", Vector2(335, 900), duration).set_trans(Tween.TRANS_LINEAR)

func _set_practice_text(text: String) -> void:
    var label := practice_panel.get_node("PracticeText") as Label
    label.text = text

func _on_start_pressed() -> void:
    _start_game()

func _start_game() -> void:
    state = GameState.PLAYING
    title_panel.visible = false
    practice_panel.visible = false
    result_panel.visible = false
    _reset_run()
    output_latency = AudioServer.get_output_latency()
    music.stop()
    music.play()
    _flash_section("LISTEN & SWING")

func _reset_run() -> void:
    events = _build_events()
    fake_triggered = [false, false]
    finished = false
    last_song_time = 0.0
    perfect_count = 0
    great_count = 0
    good_count = 0
    miss_count = 0
    panic_swings = 0
    early_count = 0
    late_count = 0
    current_section = -1
    shot_busy = false
    incoming_ball.visible = false
    shot_ball.visible = false
    fake_bird.visible = false
    fog.color.a = 0.0
    tint.color.a = 0.0
    character.position = character_base_pos
    character.scale = character_base_scale
    character.rotation = 0.0

func _build_events() -> Array:
    var raw := [
        [8.0, "normal", 2.0], [12.0, "normal", 2.0], [16.0, "normal", 2.0],
        [22.0, "special", 4.0], [28.0, "normal", 2.0], [32.0, "normal", 2.0],
        [38.0, "normal", 2.0], [44.0, "special", 4.0], [50.0, "normal", 2.0],
        [54.0, "normal", 2.0], [60.0, "normal", 2.0], [66.0, "special", 4.0],
        [72.0, "normal", 2.0], [76.0, "normal", 2.0], [82.0, "normal", 2.0],
        [88.0, "special", 4.0], [92.0, "normal", 2.0]
    ]
    var out: Array = []
    for item in raw:
        out.append({
            "beat": float(item[0]),
            "kind": String(item[1]),
            "lead": float(item[2]),
            "resolved": false,
            "result": ""
        })
    return out

func _process(_delta: float) -> void:
    if state != GameState.PLAYING:
        return
    var t := _song_time()
    var beat := t / BEAT_SEC
    _update_sections(beat)
    _update_fake_birds(beat)
    _update_incoming_ball(t)
    _resolve_expired_events(t)
    if not finished and (t >= TRACK_BEATS * BEAT_SEC or (not music.playing and t > 2.0)):
        finished = true
        _finish_game()

func _song_time() -> float:
    if not music.playing:
        return last_song_time
    var t := music.get_playback_position() + AudioServer.get_time_since_last_mix() - output_latency
    t = max(0.0, t)
    if t < last_song_time:
        t = last_song_time
    else:
        last_song_time = t
    return t

func _judged_song_time() -> float:
    return _song_time() + input_offset_ms / 1000.0

func _update_incoming_ball(t: float) -> void:
    if shot_busy:
        return
    var active: Dictionary = {}
    for event in events:
        if bool(event["resolved"]):
            continue
        var target := float(event["beat"]) * BEAT_SEC
        var cue := (float(event["beat"]) - float(event["lead"])) * BEAT_SEC
        if t >= cue and t <= target + MISS_WINDOW:
            active = event
            break
    if active.is_empty():
        incoming_ball.visible = false
        return
    var target_t := float(active["beat"]) * BEAT_SEC
    var cue_t := (float(active["beat"]) - float(active["lead"])) * BEAT_SEC
    var p := clamp((t - cue_t) / max(0.001, target_t - cue_t), 0.0, 1.15)
    var special := String(active["kind"]) == "special"
    incoming_ball.visible = true
    incoming_ball.color = Color("ffd85c") if special else Color("fffaf0")
    incoming_ball.scale = Vector2.ONE * (1.15 if special else 1.0)
    var start_y := 770.0 if special else 840.0
    incoming_ball.position = Vector2(790.0 - 455.0 * p, start_y + 80.0 * p - sin(p * PI) * (95.0 if special else 48.0))

func _resolve_expired_events(t: float) -> void:
    for event in events:
        if bool(event["resolved"]):
            continue
        var target := float(event["beat"]) * BEAT_SEC
        if t > target + MISS_WINDOW:
            event["resolved"] = true
            event["result"] = "miss"
            miss_count += 1
            _miss_reaction("late")

func _update_sections(beat: float) -> void:
    var section := 0
    if beat >= 80.0:
        section = 5
    elif beat >= 64.0:
        section = 4
    elif beat >= 48.0:
        section = 3
    elif beat >= 32.0:
        section = 2
    elif beat >= 16.0:
        section = 1
    if section == current_section:
        return
    current_section = section
    match section:
        0:
            _flash_section("BASIC SHOTS")
        1:
            _flash_section("LONG CUE")
        2:
            _flash_section("DON'T CHASE THE BIRD")
        3:
            _flash_section("TRUST YOUR EARS")
            var tw := create_tween()
            tw.tween_property(fog, "color:a", 0.38, 1.2)
        4:
            _flash_section("FAR AWAY")
            var tw := create_tween()
            tw.parallel().tween_property(character, "scale", character_base_scale * 0.82, 0.8)
            tw.parallel().tween_property(character, "position", character_base_pos + Vector2(-25, 45), 0.8)
            tw.parallel().tween_property(fog, "color:a", 0.52, 0.8)
        5:
            _flash_section("FINAL HOLE")
            var tw := create_tween()
            tw.parallel().tween_property(character, "scale", character_base_scale, 0.6)
            tw.parallel().tween_property(character, "position", character_base_pos, 0.6)
            tw.parallel().tween_property(fog, "color:a", 0.0, 0.8)
            tw.parallel().tween_property(tint, "color:a", 0.12, 0.8)

func _update_fake_birds(beat: float) -> void:
    for i in range(fake_beats.size()):
        if not fake_triggered[i] and beat >= float(fake_beats[i]) - 0.2:
            fake_triggered[i] = true
            _fly_fake_bird(i)

func _fly_fake_bird(index: int) -> void:
    fake_bird.visible = true
    fake_bird.scale = Vector2.ONE * (0.42 if index == 0 else 0.50)
    fake_bird.position = Vector2(-130, 420 if index == 0 else 330)
    var target_y := 300 if index == 0 else 480
    var tw := create_tween()
    tw.tween_property(fake_bird, "position", Vector2(850, target_y), 1.7).set_trans(Tween.TRANS_SINE)
    tw.finished.connect(func(): fake_bird.visible = false)

func _unhandled_input(event: InputEvent) -> void:
    var pressed := false
    if event is InputEventScreenTouch:
        pressed = event.pressed
    elif event is InputEventMouseButton:
        pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
    elif event is InputEventKey:
        pressed = event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE)
    if not pressed:
        return
    if state == GameState.PRACTICE:
        _handle_practice_hit()
    elif state == GameState.PLAYING:
        _handle_game_hit()

func _handle_practice_hit() -> void:
    if practice_ready_to_start:
        _start_game()
        return
    if not practice_active:
        return
    var diff := _wall_time() - practice_target_wall
    practice_active = false
    incoming_ball.visible = false
    if abs(diff) <= GOOD_WINDOW + 0.04:
        _play_sfx("res://assets/audio/success.wav")
        _character_swing(true)
        _set_practice_text("ナイス！")
        practice_step += 1
        await get_tree().create_timer(0.7).timeout
        _practice_begin_step()
    else:
        _play_sfx("res://assets/audio/whiff.wav")
        _character_swing(false)
        _set_practice_text("もう一回。音の最後の次でタップ！")
        await get_tree().create_timer(0.9).timeout
        _practice_begin_step()

func _handle_game_hit() -> void:
    var t := _judged_song_time()
    var nearest: Dictionary = {}
    var nearest_diff := 999.0
    for event in events:
        if bool(event["resolved"]):
            continue
        var target := float(event["beat"]) * BEAT_SEC
        var d := t - target
        if abs(d) < abs(nearest_diff):
            nearest = event
            nearest_diff = d
    if nearest.is_empty() or abs(nearest_diff) > MISS_WINDOW:
        panic_swings += 1
        _panic_swing()
        return

    nearest["resolved"] = true
    if nearest_diff < -0.012:
        early_count += 1
    elif nearest_diff > 0.012:
        late_count += 1

    var ad := abs(nearest_diff)
    if ad <= PERFECT_WINDOW:
        nearest["result"] = "perfect"
        perfect_count += 1
        _successful_shot(nearest_diff, 3)
    elif ad <= GREAT_WINDOW:
        nearest["result"] = "great"
        great_count += 1
        _successful_shot(nearest_diff, 2)
    else:
        nearest["result"] = "good"
        good_count += 1
        _successful_shot(nearest_diff, 1)

func _successful_shot(diff: float, quality: int) -> void:
    if shot_busy:
        return
    shot_busy = true
    incoming_ball.visible = false
    _character_swing(true)
    _play_sfx("res://assets/audio/success.wav")
    shot_ball.visible = true
    shot_ball.color = Color("fffaf0")
    shot_ball.position = Vector2(338, 900)
    shot_ball.scale = Vector2.ONE

    shot_anim_start = shot_ball.position
    shot_anim_end = Vector2(575, 525)
    shot_anim_quality = quality
    if quality == 2:
        shot_anim_end += Vector2(-40 if diff < 0 else 45, 45)
    elif quality == 1:
        shot_anim_end += Vector2(-120 if diff < 0 else 100, 115)
    var tw := create_tween()
    tw.tween_method(_update_shot_progress, 0.0, 1.0, 0.72).set_trans(Tween.TRANS_SINE)
    tw.finished.connect(_finish_shot_animation)


func _update_shot_progress(p: float) -> void:
    var base := shot_anim_start.lerp(shot_anim_end, p)
    base.y -= sin(p * PI) * (250.0 if shot_anim_quality >= 2 else 175.0)
    shot_ball.position = base
    shot_ball.scale = Vector2.ONE * lerp(1.0, 0.55, p)

func _finish_shot_animation() -> void:
    shot_ball.visible = false
    shot_busy = false
    if shot_anim_quality == 3:
        _burst(shot_anim_end, Color("ffe36e"))
        _show_status("カップそば！")
    elif shot_anim_quality == 2:
        _show_status("いいショット！")
    else:
        _show_status("あぶない！")

func _update_miss_progress(p: float) -> void:
    var base := miss_anim_start.lerp(miss_anim_end, p)
    base.y -= sin(p * PI) * 80.0
    shot_ball.position = base

func _finish_miss_animation() -> void:
    shot_ball.visible = false
    shot_busy = false
    _show_status("ポチャン…")

func _panic_swing() -> void:
    _play_sfx("res://assets/audio/whiff.wav")
    _character_swing(false)
    _show_status("スカッ")

func _miss_reaction(reason: String) -> void:
    if shot_busy:
        return
    shot_busy = true
    incoming_ball.visible = false
    _character_swing(false)
    _play_sfx("res://assets/audio/splash.wav")
    shot_ball.visible = true
    shot_ball.color = Color("fffaf0")
    shot_ball.position = Vector2(338, 900)
    miss_anim_start = Vector2(338, 900)
    miss_anim_end = Vector2(520, 1110) if reason == "late" else Vector2(760, 780)
    var tw := create_tween()
    tw.tween_method(_update_miss_progress, 0.0, 1.0, 0.55)
    tw.finished.connect(_finish_miss_animation)

func _character_swing(success: bool) -> void:
    if not is_instance_valid(character):
        return
    character.rotation = 0.0
    var tw := create_tween()
    tw.tween_property(character, "rotation", -0.10 if success else 0.07, 0.08).set_trans(Tween.TRANS_QUAD)
    tw.tween_property(character, "rotation", 0.22 if success else -0.12, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_property(character, "rotation", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
    if not success:
        var base := character.position
        var wobble := create_tween()
        wobble.tween_property(character, "position", base + Vector2(-16, 0), 0.05)
        wobble.tween_property(character, "position", base + Vector2(14, 0), 0.05)
        wobble.tween_property(character, "position", base, 0.08)

func _burst(pos: Vector2, color: Color) -> void:
    for i in range(10):
        var piece := _make_circle(5.0 + float(i % 3), color.lightened(float(i % 4) * 0.08))
        piece.position = pos
        world.add_child(piece)
        var angle := TAU * float(i) / 10.0
        var target := pos + Vector2(cos(angle), sin(angle)) * (60.0 + 10.0 * (i % 3))
        var tw := create_tween()
        tw.parallel().tween_property(piece, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tw.parallel().tween_property(piece, "modulate:a", 0.0, 0.45)
        tw.finished.connect(piece.queue_free)

func _flash_section(text: String) -> void:
    section_label.text = text
    section_label.modulate.a = 0.0
    var tw := create_tween()
    tw.tween_property(section_label, "modulate:a", 1.0, 0.12)
    tw.tween_interval(0.55)
    tw.tween_property(section_label, "modulate:a", 0.0, 0.38)

func _show_status(text: String) -> void:
    status_label.text = text
    status_label.modulate.a = 0.0
    status_label.position.y = 1010
    var tw := create_tween()
    tw.parallel().tween_property(status_label, "modulate:a", 1.0, 0.08)
    tw.parallel().tween_property(status_label, "position:y", 980.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tw.tween_interval(0.34)
    tw.tween_property(status_label, "modulate:a", 0.0, 0.24)

func _hide_status() -> void:
    status_label.modulate.a = 0.0
    section_label.modulate.a = 0.0

func _finish_game() -> void:
    state = GameState.RESULT
    music.stop()
    incoming_ball.visible = false
    shot_ball.visible = false
    _play_sfx("res://assets/audio/finish.wav")
    await get_tree().create_timer(0.45).timeout
    result_panel.visible = true
    title_panel.visible = false
    practice_panel.visible = false
    _populate_result()

func _populate_result() -> void:
    var total := max(1, events.size())
    var points := perfect_count * 3 + great_count * 2 + good_count
    var percent := 100.0 * float(points) / float(total * 3)
    if percent >= 90.0:
        result_title.text = "ノリノリ！"
    elif percent >= 72.0:
        result_title.text = "いい感じ！"
    else:
        result_title.text = "もう一回！"

    var timing_note := "ほぼ真ん中で打てている！"
    if early_count > late_count + 2:
        timing_note = "少し早めに振るクセがあるかも。"
    elif late_count > early_count + 2:
        timing_note = "少し遅め。合図の最後を信じよう。"
    var fake_note := "フェイクの小鳥にも落ち着いて対応できた。"
    if panic_swings > 0:
        fake_note = "小鳥につられた空振り: %d回" % panic_swings
    result_body.text = "スコア  %d\n\nジャスト: %d\nいい感じ: %d\nぎりぎり: %d\nミス: %d\n\n%s\n%s" % [roundi(percent), perfect_count, great_count, good_count, miss_count, timing_note, fake_note]

func _play_sfx(path: String) -> void:
    var player := AudioStreamPlayer.new()
    player.stream = load(path)
    add_child(player)
    player.finished.connect(player.queue_free)
    player.play()

func _on_offset_changed(value: float) -> void:
    input_offset_ms = value
    _update_offset_label()
    _save_settings()

func _update_offset_label() -> void:
    if offset_label != null:
        offset_label.text = "%+.0f ms" % input_offset_ms

func _load_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://sky_golf_settings.cfg") == OK:
        input_offset_ms = float(cfg.get_value("timing", "offset_ms", 0.0))

func _save_settings() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("timing", "offset_ms", input_offset_ms)
    cfg.save("user://sky_golf_settings.cfg")

func _wall_time() -> float:
    return float(Time.get_ticks_usec()) / 1000000.0
