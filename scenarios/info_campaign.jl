mutable struct Scenario_ic
	gov_agent :: Agent
	links :: Vector{Link}
	p_comm :: Float64
	p_comm_item :: Float64
	trust :: Float64
	t_start :: Float64
end

Scenario_ic(a) = Scenario_ic(a, [], 0, 0, 0, 0)

function setup_scenario(::Type{Scenario_ic}, sim::Simulation, scen_args, pars) 
	scen = Scenario_ic(Agent(sim.model.world.exits[1], 0.0))
	scen.gov_agent.info_loc = fill(Unknown, length(sim.model.world.cities))
	scen.gov_agent.info_link = fill(UnknownLink, length(sim.model.world.links))

	as = ArgParseSettings("", autofix_names=true)

	@add_arg_table! as begin
		"--p-comm"
			arg_type = Float64
			default = 0.5
		"--p-comm-item"
			arg_type = Float64
			default = 0.5
		"--trust"
			arg_type = Float64
			default = 0.5
		"--t-start"
			arg_type = Float64
			default = 220.0
		end
	
	args = parse_args(split(scen_args), as, as_symbols=true)

	scen.p_comm = args[:p_comm]
	scen.p_comm_item = args[:p_comm_item]
	scen.trust = args[:trust]
	scen.t_start = args[:t_start]

	scen
end

function update_scenario!(scen::Scenario_ic, sim::Simulation, t)
	if t < scen.t_start
		return
	end

	gov_agent = scen.gov_agent

	# setup scenario based on current state of sim
	# risk might change, so redo it every step
	empty!(scen.links)

	for link in sim.model.world.links
		if link.risk > sim.par.risk_normal
			push!(scen.links, link)

			discover_if_unknown!(gov_agent, link.l1, sim.par)
			discover_if_unknown!(gov_agent, link.l2, sim.par)
			if ! knows(gov_agent, link)
				discover!(gov_agent, link, link.l1, sim.par)
			end
			info_link = info(gov_agent, link)
			info_link.friction = TrustedF(link.friction, 0.999)
			info_link.risk = TrustedF(link.risk, 0.999)
		end
	end

	par = sim.par

	p1 = BeliefPars(par.convince^(1.0/scen.trust), par.convert^(1.0/scen.trust), par.confuse)
	p2 = BeliefPars(par.convince, par.convert, par.confuse)

	for city in sim.model.world.entries
		for a in city.people
			if rand() > scen.p_comm
				continue
			end

	#		print("I")
			
			for l in scen.links
				if rand() > scen.p_comm_item
					continue
				end

				discover_if_unknown!(a, l.l1, par)
				discover_if_unknown!(a, l.l2, par)

				exchange_link_info(l, info(a, l), info(gov_agent, l), a, gov_agent, p1, p2, par)
			end
		end
	end
end


Scenario_ic
