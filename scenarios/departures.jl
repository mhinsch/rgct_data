mutable struct Scenario_dep
	dep :: Vector{Float64}
	warmup :: Float64
	year :: Float64
end

Scenario_dep() = Scenario_dep([], 0, 0)

function setup_scenario(::Type{Scenario_dep}, sim::Simulation, scen_args, pars)
	scen = Scenario_dep()

	as = ArgParseSettings("", autofix_names=true)

	@add_arg_table! as begin
		"--dep"
			nargs = '+'
			arg_type = Float64
			required = true
		"--year"
			arg_type = Float64
			default = 100.0
		"--warmup"
			arg_type = Float64
			required = true
		end
	
	args = parse_args(split(scen_args), as, as_symbols=true)
	factors = args[:dep]
	scen.dep = [pars.rate_dep]
	for f in [1.0; factors]
		push!(scen.dep, scen.dep[end] * f)
	end
	scen.warmup = args[:warmup]
	scen.year = args[:year]

	scen
end

function update_scenario!(scen::Scenario_dep, sim::Simulation, t)
	year = t < scen.warmup ? 
		1 :
		floor(Int, (t-scen.warmup) / scen.year) + 2

	sim.par = Params(sim.par, rate_dep=scen.dep[year])
end

Scenario_dep
