function get_parfile()
	if length(ARGS) > 0 && ARGS[1][1] != '-'
		parfile = ARGS[1]
		deleteat!(ARGS, 1)
	else
		parfile = "base/params.jl"
	end

	parfile
end

function save_params(out_name, p)
        open(out_name, "w") do out
                println(out, "using Parameters")
                println(out)
                println(out, "@with_kw struct Params")
                for f in fieldnames(typeof(p))
                        println(out, "\t", f, "\t::\t", fieldtype(typeof(p), f), "\t= ", getfield(p, f))
                end
                println(out, "end")
        end
end
