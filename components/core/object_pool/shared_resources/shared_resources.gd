extends Node
## Cache có chủ sở hữu để GPU resource được nhả trước lúc RenderingServer dừng.
## Chỉ registry dùng từ luồng nạp Resource cần khóa; cache hình học chỉ truy cập lúc cấu hình trên luồng chính.

var _resources: Dictionary[StringName, Resource] = {}
var _buckets: Dictionary[StringName, Dictionary] = {}
var _values: Dictionary[StringName, Variant] = {}
var _registries: Dictionary[StringName, Array] = {}
var _registry_lock: Mutex = Mutex.new()
var _damage_modifiers: Array[Callable] = []
var _stopping: bool = false


func _ready() -> void:
	set_process(false)
	set_physics_process(false)


func _exit_tree() -> void:
	_registry_lock.lock()
	_stopping = true
	_registries.clear()
	_registry_lock.unlock()
	_damage_modifiers.clear()
	_buckets.clear()
	_resources.clear()
	_values.clear()


func get_resource(key: StringName) -> Resource:
	return _resources.get(key) as Resource


func store_resource(key: StringName, resource: Resource) -> void:
	if _stopping:
		return
	if resource == null:
		_resources.erase(key)
	else:
		_resources[key] = resource


func release_resource(key: StringName) -> void:
	_resources.erase(key)


func get_bucket(key: StringName) -> Dictionary:
	if _stopping:
		return {}
	if not _buckets.has(key):
		_buckets[key] = {}
	return _buckets[key]


func release_bucket(key: StringName) -> void:
	_buckets.erase(key)


func get_value(key: StringName, fallback: Variant = null) -> Variant:
	return _values.get(key, fallback)


func store_value(key: StringName, value: Variant) -> void:
	if not _stopping:
		_values[key] = value


func register_weak(group: StringName, resource: Resource) -> void:
	_registry_lock.lock()
	if not _stopping:
		if not _registries.has(group):
			_registries[group] = []
		var entries: Array = _registries[group]
		var exists: bool = false
		for entry: WeakRef in entries:
			if entry.get_ref() == resource:
				exists = true
				break
		if not exists:
			entries.append(weakref(resource))
	_registry_lock.unlock()


func get_registered(group: StringName) -> Array[Resource]:
	var result: Array[Resource] = []
	_registry_lock.lock()
	if _registries.has(group):
		var entries: Array = _registries[group]
		var index: int = entries.size() - 1
		while index >= 0:
			var resource: Resource = (entries[index] as WeakRef).get_ref() as Resource
			if resource == null:
				entries.remove_at(index)
			else:
				result.append(resource)
			index -= 1
	_registry_lock.unlock()
	return result


func add_damage_modifier(modifier: Callable) -> void:
	if not _stopping and modifier.is_valid() and not _damage_modifiers.has(modifier):
		_damage_modifiers.append(modifier)


func remove_damage_modifier(modifier: Callable) -> void:
	_damage_modifiers.erase(modifier)


func get_damage_modifiers() -> Array[Callable]:
	return _damage_modifiers
