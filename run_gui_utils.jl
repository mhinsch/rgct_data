function calc_scales(model, pars)
	rf_limits = r_frict_limits(model)
	scales = prop_scales(frict_limits(model)..., rf_limits...,
		qual_limits(model, pars)..., risk_limits(model)...,
		min_costs(pars, rf_limits[2]), max_costs(pars, rf_limits[1]))

	println("max(f): ", scales.max_f, "\t min(f): ", scales.min_f)
	println("max(real f): ", scales.max_rf, "\t min(real f): ", scales.min_rf)
	println("max(q): ", scales.max_q, "\t min(q): ", scales.min_q)
	println("max(r): ", scales.max_r, "\t min(r): ", scales.min_r)
	println("max(c): ", scales.max_c, "\t min(c): ", scales.min_c)

	scales
end


function setup_run_gui(run)
	gui = setup_Gui("risk&rumours", 1024, 1024, 2, 2)
	clear!(gui.canvas_bg)
	scales = calc_scales(run.sim.model, run.parameters)

	gui, scales
end
