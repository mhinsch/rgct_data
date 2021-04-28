#!/usr/bin/env julia

push!(LOAD_PATH, pwd())

include("analysis.jl")
include("base/simulation.jl")
include("base/args.jl")

include("run_utils.jl")

function run!(sim, scen_data, p, stop, log_file) 
	t = 0.0
	RRGraph.spawn(sim.model, sim)
	while t < stop
		# run scenario update functions
		for (update, dat) in scen_data
			update(dat, sim, t)
		end

		RRGraph.upto!(t + 1.0)
		t += 1.0
		analyse_log(sim.model, log_file)
		println(t, " ", RRGraph.time_now())
		flush(stdout)
	end

	sim
end


using Params2Args
using ArgParse


include(get_parfile())
	

const arg_settings = ArgParseSettings("run simulation", autofix_names=true)

@add_arg_table! arg_settings begin
	"--stop-time", "-t"
		help = "at which time to stop the simulation" 
		arg_type = Float64
		default = 50.0
	"--par-out-file"
		help = "file name for parameter output"
		default = "params_used.jl"
#	"--model-file"
#		help = "file name for model data output"
#		default = "data.txt"
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
#	"--map-dir"
#		help = "directory to search for maps"
#		default = ""
	"--scenario", "-s"
		help = "load custom scenario code"
		nargs = '+'
		action = :append_arg
	"--scenario-dir"
		help = "directory to search for scenarios"
		default = ""
end

add_arg_group!(arg_settings, "simulation parameters")
fields_as_args!(arg_settings, Params)

const args = parse_args(arg_settings, as_symbols=true)
const p = @create_from_args(args, Params)


save_params(args[:par_out_file], p)


const t_stop = args[:stop_time] 

const scenarios = load_scenarios(args[:scenario_dir], args[:scenario])

const map = args[:map]

const sim, scen_data = setup_simulation(p, scenarios, map)

const logf = open(args[:log_file], "w")
#const modelf = open(args[:model_file], "w")
const cityf = open(args[:city_out_file], "w")
const linkf = open(args[:link_out_file], "w")

prepare_outfiles(logf, cityf, linkf)

run!(sim, scen_data, p, t_stop, logf)

analyse_world(sim.model, cityf, linkf)

close(logf)
#close(modelf)
close(cityf)
close(linkf)
