
function load_scenarios(scen_dir, scen_args)
	if scen_dir != ""
		scen_dir *= "/"
	end
	scenarios = Tuple{Function, Function, Vector{String}}[]
	for scenario in scen_args
		sfile = scenario[1]
		if sfile == "none"
			continue
		end
		pars = scenario[2:end]
		setup, update = include(scen_dir * sfile * ".jl")
		push!(scenarios, (setup, update, pars))
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

	scen_data = Tuple{Function, Any}[]
	# setup scenarios
	for (setup, update, pars) in scenarios
		dat = setup(sim, pars)
		push!(scen_data, (update, dat))
	end

	sim, scen_data
end
