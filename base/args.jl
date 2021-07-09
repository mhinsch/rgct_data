function get_parfile(argv=ARGS)
	if length(argv) > 0 && argv[1][1] != '-'
		parfile = argv[1]
		deleteat!(argv, 1)
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
