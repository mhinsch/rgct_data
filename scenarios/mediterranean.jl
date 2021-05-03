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
	outfile :: IO
end

Scenario_med() = Scenario_med([])

@observe log_medit scen begin
	@show "intercept"	sum(scen.interc_count)
end

function setup_scenario(::Type{Scenario_med}, sim::Simulation, pars)
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

	scen.outfile = open("med_output.txt")
	print_header_log_medit(scen.outfile)

	scen
end

function update_scenario!(scen::Scenario_med, sim::Simulation, t)
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
	# expected number of interceptions
	# n_i = n-1 = 1/(1-p_i) - 1
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

	print_stats_log_medit(scen.outfile, scen)
end

function finish_scenario!(scen::Scenario_med, sim::Simulation)
	close(scen.outfile)
end


Scenario_med
