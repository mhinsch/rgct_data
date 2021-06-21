mutable struct Scenario_med
	"risks for sea crossings per year (1st is warmup)"
	risks_w :: Vector{Float64}
	risks_e :: Vector{Float64}
	"interception probability per year (1st is warmup)"
	interc_w :: Vector{Float64}
	interc_e :: Vector{Float64}
	"waiting time between crossing attempts"
	wait :: Float64
	"movement speed, copied from main params"
	speed :: Float64
	"how long to run before starting scenario"
	warmup :: Float64
	"list of all links that are sea crossings"
	crossings :: Vector{Link}
	is_western :: Vector{Bool}
	exits :: Vector{Location}
	is_western_x :: Vector{Bool}
	"interception count per link"
	interc_count :: Vector{Int}
	outfile :: IO
end

Scenario_med() = Scenario_med([], [], [], [], 0, 0, 0, [], [], [], [], [], stdout)

deaths(link) = link.count_deaths
arrivals(loc) = loc.count

@observe log_medit scen begin
	@show "n_interc_w"	sum(scen.interc_count[scen.is_western])
	@show "n_interc_e"	sum(scen.interc_count[.!scen.is_western])
	@show "deaths_w" 	sum(deaths.(scen.crossings[scen.is_western]))
	@show "deaths_e" 	sum(deaths.(scen.crossings[.!scen.is_western]))
	@show "arrivals_w" 	sum(arrivals.(scen.exits[scen.is_western_x]))
	@show "arrivals_e" 	sum(arrivals.(scen.exits[.!scen.is_western_x]))
end

function setup_scenario(::Type{Scenario_med}, sim::Simulation, scen_args, pars)
	scen = Scenario_med()

	as = ArgParseSettings("", autofix_names=true)

	@add_arg_table! as begin
		"--risks-w"
			nargs = '+'
			arg_type = Float64
			required = true
		"--risks-e"
			nargs = '+'
			arg_type = Float64
			required = true
		"--int-w"
			nargs = '+'
			arg_type = Float64
			required = true
		"--int-e"
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
			default = "med_int_death_arr.txt"
		end

	args = parse_args(split(scen_args), as, as_symbols=true)

	scen.speed = pars.move_speed

	# preliminary, needs changing later
	scen.risks_w = args[:risks_w]
	scen.risks_e = args[:risks_e]
	scen.interc_w = args[:int_w]
	scen.interc_e = args[:int_e]
	scen.wait = args[:wait]
	scen.warmup = args[:warmup]

	# collect links to exits (== sea crossings)
	scen.crossings = filter(sim.model.world.links) do link
			link.l1.typ==EXIT || link.l2.typ==EXIT
		end
	scen.is_western = [l.l1.pos.y < 0.5 for l in scen.crossings]

	scen.exits = sim.model.world.exits
	scen.is_western_x = [x.pos.y < 0.5 for x in scen.exits]

	scen.interc_count = zeros(Int, length(scen.crossings))

	scen.outfile = open(args[:out], "w")
	print_header_log_medit(scen.outfile)

	scen
end

function update_scenario!(scen::Scenario_med, sim::Simulation, t)
	# in case we want a longer warmup
	year = t < scen.warmup ? 
		1 :
		floor(Int, (t-scen.warmup) / 100) + 2

	@assert year <= length(scen.risks_w)

	p_i_w = scen.interc_w[year]
	# additional time for crossings
	# being intercepted adds constant s to effective distance (waiting time), then
	# the same process happens again
	# for a given probability p_i to be intercepted the expected duration is therefore:
	# E(d') = (1-p_i) d + p_i * (s + (1-p_i) d + p_i * (s + ...
	# = d + p_i/(1-p_i) s
	exp_time_w = p_i_w/(1.0-p_i_w) * scen.wait
	# expected number of interceptions
	# n_i = n-1 = 1/(1-p_i) - 1
	n_i_w = 1/(1-p_i_w) - 1

	risk_w = scen.risks_w[year]

	# same for east
	p_i_e = scen.interc_e[year]
	exp_time_e = p_i_e/(1.0-p_i_e) * scen.wait
	n_i_e = 1/(1-p_i_e) - 1
	risk_e = scen.risks_e[year]

	for i in eachindex(scen.crossings)
		l = scen.crossings[i]
		is_w = scen.is_western[i]
		# add distance so that it takes exp_time longer
		l.friction = l.distance + (is_w ? exp_time_w : exp_time_e) * scen.speed
		l.risk = is_w ? risk_w : risk_e
		# calculate interceptions (cumulative)
		scen.interc_count[i] = round(Int, (is_w ? n_i_w : n_i_e) * l.count)
	end

	print_stats_log_medit(scen.outfile, scen)
end

function finish_scenario!(scen::Scenario_med, sim::Simulation)
	close(scen.outfile)
end


Scenario_med
