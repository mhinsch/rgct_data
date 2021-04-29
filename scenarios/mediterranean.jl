mutable struct Scenario_med
	"risks for sea crossings per year"
	risks :: Vector{Float64}
	crossings :: Vector{Link}
end

Scenario_med() = Scenario_med([])

function setup_scenario_med(sim::Simulation, pars)
	scen = Scenario_med()
	if length(pars) < 1
		error("scenario data required")
	end

	# preliminary, needs changing later
	scen.risks = parse.(Float64, pars)

	# collect links to exits (== sea crossings)
	scen.crossings = filter(sim.model.world.links) do link
			link.l1.typ==EXIT || link.l2.typ==EXIT
		end

	scen
end

function scenario_med!(scen, sim::Simulation, t)
	year = floor(Int, t / 100) 

	@assert year <= length(scen.risks)

	risk = scen.risks[year]

	for l in scen.crossings
		l.risk = risk
	end
end

(setup_scenario_med, scenario_med!)
