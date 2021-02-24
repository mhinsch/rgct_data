mutable struct Scenario_ic
	gov_agent :: Agent
	links :: Vector{Links}
	p_comm :: Float64
	p_comm_item :: Float64
	trust :: Float64
	t_start :: Float64
	par :: Params
end

Scenario_ic(a, p) = Scenario_ic(a, [], 0, 0, 0, 0, p)

function setup_scenario_ic(sim::Simulation, pars) 
	scen = Scenario_ic(Agent(sim.model.world.exits[1], 0), sim.par)
	scen.gov_agent.info_loc = fill(Unknown, length(sim.model.world.cities))
	scen.gov_agent.info_link = fill(UnknownLink, length(sim.model.world.links))

	np = length(pars)
	scen.p_comm = np >= 1 ? parse(Float64, pars[1]) : 0.5
	scen.p_comm_item = np >= 2 ? parse(Float64, pars[1]) : 0.5
	scen.trust = np >= 3 ? parse(Float64, pars[1]) : 0.5
	scen.t_start = np >= 4 ? parse(Float64, pars[1]) : 0

	scen
end

function scenario_ic!(scen, sim::Simulation, t)
	if t < scen.t_start
		return
	end

	gov_agent = scen.gov_agent

	# setup scenario based on current state of sim
	if empty(scen.links)
		println("starting info campaign scenario: $(scen.p_comm), $(scen.p_comm_item), $(scen.trust)")
		# temp. patch params so that gov_agent knows everything
		setup_par = Params(sim.par, speed_expl_risk = 1.0)

		for link in sim.model.world.links
			if link.risk > par.risk_normal
				push!(scen.links, link)

				discover_if_unknown!(gov_agent, link.l1, par)
				discover_if_unknown!(gov_agent, link.l2, par)
				explore_at!(gov_agent, sim.model.world, link, link.l1, 1.0, setup_par)
			end
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

(setup_scenario_ic, scenario_ic!)
