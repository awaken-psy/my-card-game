extends Node2D

var GutRunner = load('res://addons/gut/gui/GutRunner.tscn')
var GutConfig = load('res://addons/gut/gut_config.gd')

func _ready():
	var runner = GutRunner.instantiate()
	add_child(runner)

	var cfg = GutConfig.new()
	cfg.load_options('res://.gutconfig.json')

	# Override with CLI arguments
	var args = OS.get_cmdline_args()
	for i in range(args.size()):
		var arg = args[i]
		if arg.begins_with('-g'):
			var raw = arg.substr(2)
			var eq_pos = raw.find('=')
			var flag = raw.split('=')[0]
			var val = ''
			if eq_pos >= 0:
				val = raw.substr(eq_pos + 1)
			var next_arg = args[i + 1] if i + 1 < args.size() else ''
			match flag:
				'dir', 'dirs':
					cfg.options.dirs = [val] if val else [next_arg]
				'include_subdirs':
					cfg.options.include_subdirs = true
				'exit':
					cfg.options.should_exit = true
				'exit_on_success':
					cfg.options.should_exit_on_success = true
				'log_level':
					cfg.options.log_level = int(val) if val != '' and val.is_valid_int() else cfg.options.log_level
				'selected':
					cfg.options.selected = val if val else next_arg

	runner.set_gut_config(cfg)
	runner.run_tests()
