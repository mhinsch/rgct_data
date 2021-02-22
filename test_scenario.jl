mutable struct Scenario
	done :: Bool
end

Scenario() = Scenario(false)

setup_scenario(sim::Simulation) = Scenario()

function scenario!(scen, sim::Simulation, t)
	if t > 150 && ! scen.done
		println("scenario: increasing mortality")
		set_obstacle!(sim.model.world, sim.par.obstacle..., 0.7)
		scen.done = true
	end
end
