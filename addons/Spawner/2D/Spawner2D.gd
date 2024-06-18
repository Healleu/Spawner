@tool
## A complex spawner with different type and mode
## [br]Created by Healleu
##
##	[b]Spawner type :[/b][br]
##	Area : Spawn an entity with random position inside the area[br]
##  Path : Spawn an entity on the path root[br]
##	[br]
##	[b]Spawner mode :[/b][br]
##	Quantity : Keep a minimum entity quantity in the spawner[br]
##	Timer Delay : Spawn an entity with specified frequency[br]
##	Wave : Wave spawning

class_name Spawner2D extends Node2D

## Used internally
signal _property_update

## Used to dectect body entered in spawner's area, work only in Area type
signal spawner_body_entered(body : Node2D)

## Used to dectect body exited in spawner's area, work only in Area type
signal spawner_body_exited(body : Node2D)

## Used to dectect area entered in spawner's area, work only in Area type
signal spawner_area_entered(area : Area2D)

## Used to dectect area exited in spawner's area, work only in Area type
signal spawner_area_exited(area : Area2D)

## Used to detect the last spawn entity
signal spawned(entity : Node2D)

##	Area : Spawn an entity with random position inside the shape, only Empty, circle and rectangle shape supported[br]
##  Path : Spawn an entity on the path root[br]
enum SPAWNER_TYPE{AREA, PATH}
##	Quantity : Keep a minimum entity quantity in the spawner[br]
##	Timer Delay : Spawn an entity with specified frequency[br]
##	Wave : Wave spawning
enum SPAWNER_MODE{QUANTITY, TIMER_DELAY, WAVE}

##	Array of entity that can be spawn by the spawner
@export var entities_scene : Array[PackedScene] = []

##	spawner type of the spawner
@export var spawner_type : SPAWNER_TYPE = SPAWNER_TYPE.AREA

##	spawner mode of the spawner
@export var spawner_mode : SPAWNER_MODE = SPAWNER_MODE.QUANTITY

@export_group("Type")
@export_subgroup("Path")
##	Array of the path is for path spawning, if more than one path, each entity spawn on random path
@export var spawning_path : Array[Path2D] = []
@export var _pathfollow_loop : bool = false
@export var _pathfollow_rotates : bool = false
@export_subgroup("Area")
@export var _spawning_area : CircleShape2D :
	get:
		return _spawning_area
	set(value):
		_spawning_area = value
		_property_update.emit()

@export_flags_2d_physics var _layer : int = 0
@export_flags_2d_physics var _mask : int = 0

@export_group("Mode")
@export_subgroup("Timer delay")
@export var _spawning_time : Array[float] = []

@export_subgroup("Quantity")
#@export var _shared_spawn_timer_WIP : bool = false
@export var _minimum_quantity : Array[EnemyQuantity] = []


@export_subgroup("Wave")
@export_file var _wave_file : String = ""
@export var _wave_start_delay : float = 0.0


var _timers : Array[Timer] = []
var _spawn_area : Node2D = null
var _spawn_shape : CollisionShape2D = null
var _rand : RandomNumberGenerator = null
var _waves_data : Array = []

##	Array of the current entity in the spawner, ordered with entities_scene
var entities_quantity : Array[int] = []

func _init() -> void :
	connect("_property_update", _update)
	_update()
	return

func _ready() -> void :
	notify_property_list_changed()
	# Setup random variable
	_rand = RandomNumberGenerator.new()
	_rand.randomize()
	for entity_scene_index in entities_scene.size() :
		entities_quantity.append(0)
	# Setup spawner type
	match spawner_type :
		SPAWNER_TYPE.PATH :
			_path_setup()
		SPAWNER_TYPE.AREA :
			_area_setup()
	# Setup spawner mode
	match spawner_mode :
		SPAWNER_MODE.TIMER_DELAY :
			_timer_delay_setup()
		SPAWNER_MODE.QUANTITY :
			_quantity_setup()
		SPAWNER_MODE.WAVE :
			_wave_setup()
	return

func _process(delta : float) -> void :
	if not Engine.is_editor_hint() :
		# Setup spawner mode
		match spawner_mode :
			SPAWNER_MODE.QUANTITY :
				_quantity_process(delta)
	return
#### PATH ####

func _path_setup() -> void:
	if not spawning_path :
		push_error("No Root Path define")
	return

func _path_spawn(entity_scene : PackedScene) -> void :
	if spawning_path.size() :
		# create PathFollow2D
		var pathfollow : PathFollow2D = PathFollow2D.new()
		pathfollow.loop = _pathfollow_loop
		pathfollow.rotates = _pathfollow_rotates
		var path : Path2D = spawning_path.pick_random()
		path.call_deferred("add_child", pathfollow)
		# Attach Entity to PathFollow2D
		var entity : Node2D = _spawn_entity(entity_scene, Vector2(0,0))
		entity.get_node("MotionComponent").path_follow = pathfollow
		pathfollow.call_deferred("add_child", entity)
	return

#### AREA ####

func _area_setup() -> void :
	if _spawning_area :
		_spawn_area.collision_layer = _layer
		_spawn_area.collision_mask = _mask
	return

func _area_spawn(entity_scene : PackedScene) -> void :
	var random_pos : Vector2 = Vector2.ZERO
	if _spawn_area :
		if _spawning_area:
			var shape : Shape2D = _spawn_shape.get_shape()
			var shape_type : String = shape.get_class()
			match shape_type :
				"CircleShape2D" :
					var random_angle : float = _rand.randf_range(0, 2 * PI)
					var random_radius : float = _rand.randf_range(0, shape.radius)
					random_pos = Vector2(random_radius * cos(random_angle), random_radius * sin(random_angle))
				"RectangleShape2D" :
					var random_width : float = _rand.randf_range(- shape.size.x / 2, shape.size.x / 2)
					var random_height : float = _rand.randf_range(- shape.size.x / 2, shape.size.y / 2)
					random_pos = Vector2(random_width, random_height)
				_ : 
					push_warning("Shape not supported, WIP / ask the author")
		var entity : Node2D = _spawn_entity(entity_scene, random_pos)
		if is_instance_valid(entity) :
			call_deferred("add_child", entity)
	return

#### TIMER DELAY ####

func _timer_delay_setup() -> void :
	var entity_number : int = entities_scene.size() 
	if entity_number > _spawning_time.size() :
		push_error("Missing spawning time for entity")
		return
	for entity_scene_index in entity_number :
		_create_spawn_timer(entities_scene[entity_scene_index], 1, _spawning_time[entity_scene_index], false, true)
	return

##### QUANTITY #####

func _quantity_setup() -> void :
	var entity_number : int = entities_scene.size() 
	if entity_number > _minimum_quantity.size() :
		push_error("Missing spawning quantity for entity")
		set_process(false)
		return
	for entity_scene_index in entity_number :
		_create_spawn_timer(entities_scene[entity_scene_index], 1, _minimum_quantity[entity_scene_index].time_respawn_delay, true)
	return

func _quantity_process(_delta : float) -> void :
	for entity_scene_index in entities_scene.size() :
		if entities_quantity[entity_scene_index] < _minimum_quantity[entity_scene_index].enemy_quantity :
			var timer : Timer = _timers[entity_scene_index]
			if timer.get_time_left() == 0.0 :
				timer.start()
	return

#### WAVE ####

func _data_is_valid_format() -> bool :
	var valid : bool = true
	for wave_index in _waves_data.size() :
		if _waves_data[wave_index].has("time") :
			if _waves_data[wave_index].has("entity_delay") :
				if _waves_data[wave_index].has("quantity") :
					break
			valid = valid and false
	return valid

func _wave_setup() -> void :
	if not _wave_file.ends_with(".json") :
		push_error("Wave file not in json format")
		return
	var data : Array = _load_JSON(_wave_file)
	if data :
		if typeof(data) != TYPE_ARRAY :
			push_error("Wave invalid data")
			return
	else :
		return
	_waves_data = data
	if _data_is_valid_format() :
		for wave : Dictionary in _waves_data :
			var wave_time : float = wave.time
			var wave_quantity : Array = wave.quantity
			var wave_entity_delay : float = wave.entity_delay
			if wave_entity_delay :
				_wave_spawn_shift(wave_time, wave_quantity, wave_entity_delay)
			else :
				_wave_spawn_unique(wave_time, wave_quantity)
	return

func _wave_spawn_unique(wave_time : float , wave_entities_quantity : Array) -> void :
	var wave_start_time : float = wave_time + _wave_start_delay
	if wave_entities_quantity.size() > entities_scene.size() :
		push_error("Not enough entity scene")
		return
	if wave_start_time :
		for entity_index in wave_entities_quantity.size() :
			var entity_scene : PackedScene = entities_scene[entity_index]
			var quantity : int = wave_entities_quantity[entity_index]
			_create_spawn_timer(entity_scene, quantity, wave_start_time, true, true)
	else :
		for entity_index in wave_entities_quantity.size() :
			var entity_scene : PackedScene = entities_scene[entity_index]
			var quantity : int = wave_entities_quantity[entity_index]
			_on_spawn_timer(null, entity_scene, quantity)
	return
	
func _wave_spawn_shift(wave_time : float , wave_entities_quantity : Array, wave_entity_delay : float) -> void :
	var wave_start_time : float = wave_time + _wave_start_delay
	for entity_index in wave_entities_quantity.size() :
		var entity_scene : PackedScene = entities_scene[entity_index]
		var quantity : int = wave_entities_quantity[entity_index]
		for entity_number in quantity :
			var time_spawn : float = wave_start_time + entity_number * wave_entity_delay
			if time_spawn :
				_create_spawn_timer(entity_scene, 1, time_spawn, true, true)
			else :
				_on_spawn_timer(null, entity_scene, 1)
	return
	
#### EDITOR TOOL ####

func _clear_children() -> void :
	for child in get_children() :
		child.call_deferred("queue_free")
	return
	
func _update_spawn_area() -> void :
	if spawner_type == SPAWNER_TYPE.AREA :
		if _spawning_area :
			_spawn_area = Area2D.new()
			_spawn_shape = CollisionShape2D.new()
			_spawn_shape.set_shape(_spawning_area)
			_spawn_area.call_deferred("add_child", _spawn_shape)
			_spawn_area.area_entered.connect(_on_spawner_area_entered)
			_spawn_area.area_exited.connect(_on_spawner_area_exited)
			_spawn_area.body_entered.connect(_on_spawner_body_entered)
			_spawn_area.body_exited.connect(_on_spawner_body_exited)
			call_deferred("add_child", _spawn_area)
#		else :
#			_spawn_area = Node2D.new()
#			call_deferred("add_child", _spawn_area)
	return
	
func _update() -> void :
	_clear_children()
	_update_spawn_area()
	return

#### UTILS ####

func _create_spawn_timer(entity_scene : PackedScene, entity_quantity : int, wait_time : float, one_shot : bool = false, autostart : bool = false) -> void:
	if wait_time and entity_scene :
		var timer : Timer = Timer.new()
		timer.set_one_shot(one_shot)
		timer.set_autostart(autostart)
		timer.set_wait_time(wait_time)
		timer.timeout.connect(_on_spawn_timer.bind(timer, entity_scene, entity_quantity))
		_timers.append(timer)
		call_deferred("add_child", timer)
	return

func _spawn_entity(entity_scene : PackedScene, entity_position : Vector2) -> Node2D :
	if entity_scene :
		var entity : Node2D = entity_scene.instantiate()
		entity.position = entity_position
		entity.tree_entered.connect(_entity_spawn.bind(entity_scene))
		entity.tree_exited.connect(_entity_dead.bind(entity_scene))
		entity.ready.connect(_on_entity_ready.bind(entity))
		return entity
	push_error("Invalid entity scene")
	return null

func _on_entity_ready(entity : Node2D) -> void :
	emit_signal("spawned", entity)
	return

#### CALLBACK ####

func _on_spawn_timer(timeout_timer : Timer, entity_scene : PackedScene, entity_quantity : int = 1) -> void :
	if entity_scene :
		match spawner_type :
			SPAWNER_TYPE.PATH :
				for entity_index in entity_quantity :
					_path_spawn(entity_scene)
			SPAWNER_TYPE.AREA :
				for entity_index in entity_quantity :
					_area_spawn(entity_scene)
	if spawner_mode == SPAWNER_MODE.WAVE :
		if timeout_timer :
			timeout_timer.call_deferred("queue_free")
	return

func _entity_spawn(entity_scene : PackedScene) -> void :
	entities_quantity[entities_scene.find(entity_scene)] += 1
	return
	
func _entity_dead(entity_scene : PackedScene) -> void :
	entities_quantity[entities_scene.find(entity_scene)] -= 1
	return

func _on_spawner_area_entered(area : Area2D) -> void :
	emit_signal("spawner_area_entered", area)
	return
	
func _on_spawner_area_exited(area : Area2D) -> void :
	emit_signal("spawner_area_exited", area)
	return
	
func _on_spawner_body_entered(body : Node2D) -> void :
	emit_signal("spawner_body_entered", body)
	return
	
func _on_spawner_body_exited(body : Node2D) -> void :
	emit_signal("spawner_area_exited", body)
	return





func _load_JSON(path : String) -> Variant :
	if path.ends_with(".json") :
		if FileAccess.file_exists(path):
			var file : FileAccess = FileAccess.open(path, FileAccess.READ)
			var data_str : String = file.get_as_text()
			var data : Variant = JSON.parse_string(data_str)
			return data
		else:
			push_error("File not found")
	else :
		push_error("File is not in .json format")
	return null
