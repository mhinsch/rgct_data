#!/usr/bin/env julia

push!(LOAD_PATH, pwd())

include("analysis.jl")
include("base/simulation.jl")
include("base/args.jl")

include("run_utils.jl")

function run!(run) 
	t = 0.0

	logs = setup_logs()

	RRGraph.spawn(run.sim.model, run.sim)
	while t < run.t_stop
		# run scenario update functions
		run_scenarios!(run, t)
		# run simulation proper
		RRGraph.upto!(t + 1.0)
		# write logs
		run_logs(logs, t, run)

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
