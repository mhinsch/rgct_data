mutable struct Scenario_med
	"risks for sea crossings per year"
	risks :: Vector{Float64}
	"interception probability per year"
	interc :: Vector{Float64}
	"waiting time between crossing attempts"
	wait :: Float64
	"movement speed, copied from main params"
	speed :: Float64
	"list of all links that are sea crossings"
	crossings :: Vector{Link}
	"interception count per link"
	interc_count :: Vector{Int}
end

Scenario_med() = Scenario_med([])

function setup_scenario_med(sim::Simulation, pars)
	scen = Scenario_med()
	if length(pars) < 1
		error("scenario data required")
	end

	scen.speed = pars.move_speed

	# preliminary, needs changing later
	scen.risks = parse.(Float64, pars)

	# collect links to exits (== sea crossings)
	scen.crossings = filter(sim.model.world.links) do link
			link.l1.typ==EXIT || link.l2.typ==EXIT
		end

	scen.interc_count = zeros(Int, length(scen.crossings))

	scen
end

function scenario_med!(scen, sim::Simulation, t)
	year = floor(Int, t / 100) + 1

	@assert year <= length(scen.risks)

	p_i = scen.interc[year]
	# additional time for crossings
	# being intercepted adds constant s to effective distance (waiting time), then
	# the same process happens again
	# for a given probability p_i to be intercepted the expected duration is therefore:
	# E(d') = (1-p_i) d + p_i * (s + (1-p_i) d + p_i * (s + ...
	# = d + p_i/(1-p_i) s
	exp_time = p_i/(1.0-p_i) * scen.wait
	n_i = 1/(1-p_i) - 1

	risk = scen.risks[year]

	for i in eachindex(scen.crossings)
		l = scen.crossings[i]
		# add distance so that it takes exp_time longer
		l.friction = l.distance + exp_time * scen.speed
		l.risk = risk
		# calculate interceptions (cumulative)
		scen.interc_count[i] = round(Int, n_i * l.count)
	end
end

(setup_scenario_med, scenario_med!)
