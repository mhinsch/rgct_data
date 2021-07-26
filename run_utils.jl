using Params2Args
using ArgParse


function create_params(argv, par_type)
	arg_settings = ArgParseSettings("run simulation", autofix_names=true)

	@add_arg_table! arg_settings begin
		"--stop-time", "-t"
			help = "at which time to stop the simulation" 
			arg_type = Float64
			default = 50.0
		"--par-out-file"
			help = "file name for parameter output"
			default = "params_used.jl"
		"--city-out-file"
			help = "file name for city data output"
			default = "cities.txt"
		"--link-out-file"
			help = "file name for link data output"
			default = "links.txt"
		"--log-file", "-l"
			help = "file name for log"
			default = "log.txt"
		"--map", "-m"
			help = "load map in JSON format"
			default = ""
		"--scenario", "-s"
			help = "load custom scenario code"
			nargs = 2
			action = :append_arg
		"--scenario-dir"
			help = "directory to search for scenarios"
			default = ""
	end

	add_arg_group!(arg_settings, "simulation parameters")
	fields_as_args!(arg_settings, par_type)

	args = parse_args(argv, arg_settings, as_symbols=true)
	p = @create_from_args(args, par_type)

	args, p
end


function process_parameters(argv = ARGS)
	include(get_parfile(argv))
	
	args, p = create_params(argv, Params)

	save_params(args[:par_out_file], p)

	args, p
end


function finish_scenario!(dat, sim)
end

function load_scenarios(scen_dir, scen_args)
	if scen_dir != ""
		scen_dir *= "/"
	end
	scenarios = Tuple{Type, String}[]
	for scenario in scen_args
		sfile = scenario[1]
		if sfile == "none"
			continue
		end
		pars = scenario[2]
		scen_type = include(scen_dir * sfile * ".jl")
		push!(scenarios, (scen_type, pars))
	end

	scenarios
end


function setup_simulation(p, scenarios, map_fname)
	world = 
		if map_fname != "" 
			# load map
			open(file -> setup_model(p, file), map_fname)
		else
			# generate map
			setup_model(p)
		end

	sim = Simulation(world, p)

	scen_data = []
	# setup scenarios
	for (scen_type, pars) in scenarios
		dat = Base.@invokelatest setup_scenario(scen_type, sim, pars, p)
		push!(scen_data, dat)
	end

	sim, scen_data
end


function setup_run()
	args, parameters = process_parameters()

	t_stop = args[:stop_time] 

	scen_inis = load_scenarios(args[:scenario_dir], args[:scenario])

	mapf = args[:map]

	sim, scenarios = setup_simulation(parameters, scen_inis, mapf)

	logf = open(args[:log_file], "w")
	cityf = open(args[:city_out_file], "w")
	linkf = open(args[:link_out_file], "w")
	prepare_outfiles(logf, cityf, linkf)

	(; args, parameters, scenarios, sim, t_stop, logf, cityf, linkf )
end


function cleanup_run(run)
	close(run.logf)
	close(run.cityf)
	close(run.linkf)
end
