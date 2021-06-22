mutable struct Scenario_obstfrict
	done :: Bool
	p1 :: Pos
	p2 :: Pos
	friction :: Float64
	start :: Float64
end

Scenario_obstfrict() = Scenario_obstfrict(false, Nowhere, Nowhere, 0, 0)

function setup_scenario(::Type{Scenario_obstfrict}, sim::Simulation, scen_args, pars)
	scen = Scenario_obstfrict()

	as = ArgParseSettings("", autofix_names=true)
	@add_arg_table! as begin
		"--start"
			arg_type = Float64
			required = true
		"--pos1"
			arg_type = Float64
			nargs = 2
			required = true
		"--pos2"
			arg_type = Float64
			nargs = 2
			required = true
		"--friction"
			arg_type = Float64
			required = true
		end
	args = parse_args(split(scen_args), as, as_symbols=true)

	scen.start = args[:start]
	scen.p1 = Pos(args[:pos1]...)
	scen.p2 = Pos(args[:pos2]...)
	scen.friction = args[:friction]

	scen
end

function update_scenario!(scen::Scenario_obstfrict, sim::Simulation, t)
	if t > scen.start && ! scen.done
		for l in sim.model.world.links do
			if intersect(scen.p1, scen.p2, l.l1.pos, l.l2.pos)
				l.friction = scen.friction
			end
		end
		scen.done = true
	end
end

Scenario_obstfrict
