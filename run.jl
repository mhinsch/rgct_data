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
		for dat in scen_data
			update_scenario!(dat, sim, t)
		end
		# run simulation proper
		RRGraph.upto!(t + 1.0)
		t += 1.0
		analyse_log(sim.model, log_file, RRGraph.time_now())
		println(t, " ", RRGraph.time_now())
		flush(stdout)
	end

	sim
end

	
const args, p = process_parameters()

const t_stop = args[:stop_time] 

const scenarios = load_scenarios(args[:scenario_dir], args[:scenario])

const map = args[:map]

const sim, scen_data = setup_simulation(p, scenarios, map)

const logf = open(args[:log_file], "w")
const cityf = open(args[:city_out_file], "w")
const linkf = open(args[:link_out_file], "w")

prepare_outfiles(logf, cityf, linkf)

run!(sim, scen_data, p, t_stop, logf)

analyse_world(sim.model, cityf, linkf)

for dat in scen_data
	finish_scenario!(dat, sim)
end

close(logf)
close(cityf)
close(linkf)
