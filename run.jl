#!/usr/bin/env julia

push!(LOAD_PATH, pwd())

include("analysis.jl")
include("base/simulation.jl")
include("base/args.jl")

include("run_utils.jl")

function run!(run) 
	t = 0.0
	logt = 0.0
	dumpt = -1.0	# dump c/l at 49, 99, ...
	logf = 1.0
	dumpf = 50.0

	RRGraph.spawn(run.sim.model, run.sim)
	while t < run.t_stop
		# run scenario update functions
		for scen in run.scenarios
			update_scenario!(scen, run.sim, t)
		end
		# run simulation proper
		RRGraph.upto!(t + 1.0)

		if t - logt >= logf
			analyse_log(run.sim.model, run.logf)
			logt = t
		end

		if t - dumpt >= dumpf
			analyse_world(run.sim.model, run.cityf, run.linkf, t)
			dumpt = t
		end

		t += 1.0
		println(t, " ", RRGraph.time_now())
		flush(stdout)
	end

	for scen in run.scenarios
		finish_scenario!(scen, run.sim)
	end

	run.sim
end

	
include("run_utils.jl")


const run = setup_run()

run!(run)

cleanup_run(run)
