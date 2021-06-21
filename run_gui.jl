using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer 

push!(LOAD_PATH, pwd())
using SSDL
using SimpleGui

include("run_utils.jl")


function draw(model, par, gui, focus_agent, scales, k_draw_mode, clear=false)
	copyto!(gui.canvas, gui.canvas_bg)
	draw_people!(gui.canvas, model)
	update!(gui.panels[1, 1], gui.canvas)

	if clear
		clear!(gui.canvas)
		draw_visitors!(gui.canvas, model, k_draw_mode)
		update!(gui.panels[2, 1], gui.canvas)
		count = 0
	end

	clear!(gui.canvas)
	agent = draw_rand_knowledge!(gui.canvas, model, par, scales, focus_agent, k_draw_mode)
	update!(gui.panels[1, 2], gui.canvas)

	clear!(gui.canvas)
	draw_rand_social!(gui.canvas, model, 3, agent)
	update!(gui.panels[2, 2], gui.canvas)
end


function run!(sim, scen_data, parameters, gui, t_stop, scales)
	t = 1.0
	step = 1.0
	start(sim)

	focus_agent = nothing
	k_draw_mode = ACCURACY
	n_modes = length(instances(KNOWL_DRAW_MODE))
	redraw_bg = true
	pause = false

	quit = false
	count = 1
	while ! quit
		if pause
			sleep(0.03)
		else
			# run scenario update functions
			for dat in scen_data
				update_scenario!(dat, sim, t)
			end
			t1 = time()
			RRGraph.upto!(t)
			t += step
			dt = time() - t1

			if dt > 0.1
				step /= 1.1
			elseif dt < 0.03
				step *= 1.1
			end

			if t_stop > 0 && t >= t_stop
				break
			end
 
			n_m = length(sim.model.migrants)
			n_p = length(sim.model.people)
			n_d = length(sim.model.deaths)
			println(t, " #migrants: ", n_m, " #arrived: ", n_p - n_m, " #deaths: ", n_d)
		end
		
		while (ev = SDL2.event()) != nothing
			if typeof(ev) <: SDL2.KeyboardEvent #|| typeof(ev) <: SDL2.QuitEvent
				if ev._type == SDL2.KEYDOWN
					key = ev.keysym.sym
					if key == SDL2.SDLK_ESCAPE || key == SDL2.SDLK_q
						quit = true
						break;
					elseif key == SDL2.SDLK_k
						k_draw_mode = KNOWL_DRAW_MODE((Int(k_draw_mode) + 1) % n_modes)
						println("setting knowledge draw mode: ", k_draw_mode)
						redraw_bg = true
					elseif key == SDL2.SDLK_j
						k_draw_mode = KNOWL_DRAW_MODE((Int(k_draw_mode) + n_modes - 1) % n_modes)
						println("setting knowledge draw mode: ", k_draw_mode)
						redraw_bg = true
					elseif key == SDL2.SDLK_r && length(sim.model.migrants) > 0
						focus_agent = rand(sim.model.migrants)
					elseif key == SDL2.SDLK_e && length(sim.model.migrants) > 0
						focus_agent = sim.model.people[end]
					elseif key == SDL2.SDLK_d && focus_agent != nothing
						open("agent.txt", "w") do file
							dump(file, focus_agent)
						end
					elseif key == SDL2.SDLK_p || key == SDL2.SDLK_SPACE
						pause = ! pause
					end
				end
			end
		end

		if (focus_agent == nothing || arrived(focus_agent) || dead(focus_agent)) 
			if length(sim.model.migrants) > 0
				focus_agent = sim.model.people[end]
			else
				focus_agent = nothing
			end
		end

		t1 = time()
		if redraw_bg
			draw_bg!(gui.canvas_bg, sim.model, scales, parameters, k_draw_mode)
			redraw_bg = false
		end
		draw(sim.model, sim.par, gui, focus_agent, scales, k_draw_mode, count==1)
		count = count % 10 + 1
		#println("dt: ", time() - t1)
		render!(gui)
		#println("dt2: ", time() - t1)
	end
end


include("analysis.jl")
include("base/simulation.jl")
include("base/draw.jl")
include("base/args.jl")


const args, parameters = process_parameters()

const t_stop = args[:stop_time] 

const scenarios = load_scenarios(args[:scenario_dir], args[:scenario])

const mapf = args[:map]

const sim, scen_data = setup_simulation(parameters, scenarios, mapf)

const gui = setup_Gui("risk&rumours", 1024, 1024, 2, 2)

clear!(gui.canvas_bg)
const rf_limits = r_frict_limits(sim.model)
const scales = prop_scales(frict_limits(sim.model)..., rf_limits...,
	qual_limits(sim.model, parameters)..., risk_limits(sim.model)...,
	min_costs(parameters, rf_limits[2]), max_costs(parameters, rf_limits[1]))

println("max(f): ", scales.max_f, "\t min(f): ", scales.min_f)
println("max(real f): ", scales.max_rf, "\t min(real f): ", scales.min_rf)
println("max(q): ", scales.max_q, "\t min(q): ", scales.min_q)
println("max(r): ", scales.max_r, "\t min(r): ", scales.min_r)
println("max(c): ", scales.max_c, "\t min(c): ", scales.min_c)

const logf = open(args[:log_file], "w")
const cityf = open(args[:city_out_file], "w")
const linkf = open(args[:link_out_file], "w")
prepare_outfiles(logf, cityf, linkf)

run!(sim, scen_data, parameters, gui, t_stop, scales)

analyse_world(sim.model, cityf, linkf)

for dat in scen_data
	finish_scenario!(dat, sim)
end

close(logf)
close(cityf)
close(linkf)

SDL2.Quit()
