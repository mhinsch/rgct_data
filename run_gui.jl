using SimpleDirectMediaLayer.LibSDL2

push!(LOAD_PATH, pwd())
using SSDL
using SimpleGui


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


function run!(run, gui, scales)
	t = 0.0
	step = 1.0
	
	logt = 0.0
	dumpt = -1.0	# dump c/l at 49, 99, ...
	logf = 1.0
	dumpf = 50.0

	start(run.sim)

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
			for scen in run.scenarios
				update_scenario!(scen, run.sim, t)
			end
			t1 = time()
			RRGraph.upto!(t)
			dt = time() - t1

			if dt > 0.1
				step /= 1.1
			elseif dt < 0.03
				step *= 1.1
			end

			if t - logt >= logf
				analyse_log(run.sim.model, run.logf)
				logt = t
			end

			if t - dumpt >= dumpf
				analyse_world(run.sim.model, run.cityf, run.linkf, t)
				dumpt = t
			end

			n_m = length(run.sim.model.migrants)
			n_p = length(run.sim.model.people)
			n_d = length(run.sim.model.deaths)
			println(t, " #migrants: ", n_m, " #arrived: ", n_p - n_m, " #deaths: ", n_d)

			t += step
			if run.t_stop > 0 && t >= run.t_stop
				break
			end
		end
		
		event_ref = Ref{SDL_Event}()
        while Bool(SDL_PollEvent(event_ref))
            evt = event_ref[]
            evt_ty = evt.type
			if evt_ty == SDL_QUIT
                quit = true
                break
            elseif evt_ty == SDL_KEYDOWN
                scan_code = evt.key.keysym.scancode
                if scan_code == SDL_SCANCODE_ESCAPE || scan_code == SDL_SCANCODE_Q
					quit = true
					break
				elseif scan_code == SDL_SCANCODE_K
					k_draw_mode = KNOWL_DRAW_MODE((Int(k_draw_mode) + 1) % n_modes)
					println("setting knowledge draw mode: ", k_draw_mode)
					redraw_bg = true
				elseif scan_code == SDL_SCANCODE_J
					k_draw_mode = KNOWL_DRAW_MODE((Int(k_draw_mode) + n_modes - 1) % n_modes)
					println("setting knowledge draw mode: ", k_draw_mode)
					redraw_bg = true
				elseif scan_code == SDL_SCANCODE_R && length(run.sim.model.migrants) > 0
					focus_agent = rand(run.sim.model.migrants)
				elseif scan_code == SDL_SCANCODE_E && length(run.sim.model.migrants) > 0
					focus_agent = run.sim.model.people[end]
				elseif scan_code == SDL_SCANCODE_D && focus_agent != nothing
					open("agent.txt", "w") do file
						dump(file, focus_agent)
					end
                elseif scan_code == SDL_SCANCODE_P || scan_code == SDL_SCANCODE_SPACE
					pause = !pause
                    break
                else
                    break
                end
            end
		end

		if (focus_agent == nothing || arrived(focus_agent) || dead(focus_agent)) 
			if length(run.sim.model.migrants) > 0
				focus_agent = run.sim.model.people[end]
			else
				focus_agent = nothing
			end
		end

		t1 = time()
		if redraw_bg
			draw_bg!(gui.canvas_bg, run.sim.model, scales, run.parameters, k_draw_mode)
			redraw_bg = false
		end
		draw(run.sim.model, run.parameters, gui, focus_agent, scales, k_draw_mode, count==1)
		count = count % 10 + 1
		#println("dt: ", time() - t1)
		render!(gui)
		#println("dt2: ", time() - t1)
	end

	for scen in run.scenarios
		finish_scenario!(scen, run.sim)
	end
end


include("analysis.jl")
include("base/simulation.jl")
include("base/draw.jl")
include("base/args.jl")

include("run_utils.jl")
include("run_gui_utils.jl")


const run = setup_run()

const gui, scales = setup_run_gui(run)

run!(run, gui, scales)

cleanup_run(run)

SDL_Quit()
