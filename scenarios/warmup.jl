mutable struct Scenario_warmup
	t_warmup :: Float64
	rate_dep :: Float64
end

Scenario_dep() = Scenario_dep([], 0, 0)

function setup_scenario(::Type{Scenario_dep}, sim::Simulation, scen_args, pars)
	scen = Scenario_dep()

	as = ArgParseSettings("", autofix_names=true)
	@add_arg_table! as begin
		"--t-warmup"
			arg_type = Float64
			required = true
		end
	args = parse_args(split(scen_args), as, as_symbols=true)

	scen.t_warmup = args[:warmup]
	# keep "real" rate since we will overwrite it in update
	scen.rate_dep = pars.rate_dep

	scen
end

function update_scenario!(scen::Scenario_dep, sim::Simulation, t)
	r = max(1.0, scen.rate_dep * min(t / scen.t_warmup, 1.0))

	sim.par = Params(sim.par, rate_dep=r)
end

Scenario_dep
