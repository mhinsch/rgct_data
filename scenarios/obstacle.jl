mutable struct Scenario_obst
	done :: Bool
end

Scenario_obst() = Scenario_obst(false)

setup_scenario_obst(sim::Simulation) = Scenario_obst()

function scenario_obst!(scen, sim::Simulation, t)
	if t > 45 && ! scen.done
		println("scenario_obst: increasing mortality")
		set_obstacle!(sim.model.world, sim.par.obstacle..., 0.7)
		scen.done = true
	end
end

(setup_scenario_obst, scenario_obst!)
