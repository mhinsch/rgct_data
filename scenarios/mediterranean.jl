mutable struct Scenario_med
	"risks for sea crossings per year (1st is warmup)"
	risks :: Vector{Float64}
	"interception probability per year (1st is warmup)"
	interc :: Vector{Float64}
	"waiting time between crossing attempts"
	wait :: Float64
	"movement speed, copied from main params"
	speed :: Float64
	"how long to run before starting scenario"
	warmup :: Float64
	"list of all links that are sea crossings"
	crossings :: Vector{Link}
	"interception count per link"
	interc_count :: Vector{Int}
	outfile :: IO
end

Scenario_med() = Scenario_med([], [], 0, 0, 0, [], [], stdout)

@observe log_medit scen begin
	@show "n_interc"	sum(scen.interc_count)
end

function setup_scenario(::Type{Scenario_med}, sim::Simulation, scen_args, pars)
	scen = Scenario_med()

	as = ArgParseSettings("", autofix_names=true)

	@add_arg_table! as begin
		"--risks"
			nargs = '+'
			arg_type = Float64
			required = true
		"--int"
			nargs = '+'
			arg_type = Float64
			required = true
		"--wait"
			arg_type = Float64
			required = true
		"--warmup"
			arg_type = Float64
			required = true
		"--out"
			default = "interceptions.txt"
		end

	args = parse_args(split(scen_args), as, as_symbols=true)

	scen.speed = pars.move_speed

	# preliminary, needs changing later
	scen.risks = args[:risks]
	scen.interc = args[:int]
	scen.wait = args[:wait]
	scen.warmup = args[:warmup]

	# collect links to exits (== sea crossings)
	scen.crossings = filter(sim.model.world.links) do link
			link.l1.typ==EXIT || link.l2.typ==EXIT
		end

	scen.interc_count = zeros(Int, length(scen.crossings))

	scen.outfile = open(args[:out], "w")
	print_header_log_medit(scen.outfile)

	scen
end

function update_scenario!(scen::Scenario_med, sim::Simulation, t)
	year = t < scen.warmup ? 
		1 :
		floor(Int, (t-scen.warmup) / 100) + 2

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
