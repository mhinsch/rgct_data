mutable struct Scenario_dep
	done :: Bool
end

Scenario_dep() = Scenario_dep(false)

setup_scenario_dep(sim::Simulation) = Scenario_dep()

function scenario_dep!(scen, sim::Simulation, t)
	if t > 40 && ! scen.done
		println("scenario: increasing departure rate")
		sim.par = Params(sim.par, rate_dep = 30)
		scen.done = true
	end
end


(setup_scenario_dep, scenario_dep!)
