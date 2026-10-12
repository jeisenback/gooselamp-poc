extends TestCase

## Test isolation and structure guards: every static variable has to be
## accounted for in TestHooks, and groups are named by constants.

func test_every_static_variable_is_reset_or_explained() -> void:
	for found in _static_vars():
		var covered: bool = TestHooks.RESET.has(found) or TestHooks.EXPLAINED.has(found)
		assert_true(covered, "%s is a static variable: reset it in TestHooks.reset or explain it in TestHooks.EXPLAINED" % found)
	for listed in TestHooks.RESET + TestHooks.EXPLAINED.keys():
		assert_true(_static_vars().has(listed), "%s is listed in TestHooks but is not a static variable any more" % listed)

func test_groups_are_named_by_constants_not_strings() -> void:
	var pattern := RegEx.create_from_string("(add_to_group|remove_from_group|get_nodes_in_group|get_first_node_in_group|is_in_group|call_group)\\(\\s*[\"']")
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://scripts/" + file)
		var lines := text.split("\n")
		for i in range(lines.size()):
			if pattern.search(lines[i]) != null:
				assert_true(false, "%s:%d names a group with a string: %s" % [file, i + 1, lines[i].strip_edges()])

## "Class.name" for every `static var` in the scripts.
func _static_vars() -> Array:
	var found: Array = []
	var declaration := RegEx.create_from_string("^static var (\\w+)")
	var class_line := RegEx.create_from_string("^class_name (\\w+)")
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd"):
			continue
		var owner_name := file.get_basename()
		var names: Array = []
		for line in FileAccess.get_file_as_string("res://scripts/" + file).split("\n"):
			var named := class_line.search(line)
			if named != null:
				owner_name = named.get_string(1)
			var decl := declaration.search(line)
			if decl != null:
				names.append(decl.get_string(1))
		for n in names:
			found.append("%s.%s" % [owner_name, n])
	return found
