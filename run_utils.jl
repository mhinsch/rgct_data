
function load_scenarios(scen_dir, scen_args)
	if scen_dir != ""
		scen_dir *= "/"
	end
	scenarios = (Type, eltype(scen_args))[]
	for scenario in scen_args
		sfile = scenario[1]
		if sfile == "none"
			continue
		end
		pars = scenario[2:end]
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
		dat = setup_scenario(scen_type, sim, pars)
		push!(scen_data, dat)
	end

	sim, scen_data
end
