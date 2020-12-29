function get_parfile()
	if length(ARGS) > 0 && ARGS[1][1] != '-'
		parfile = ARGS[1]
		deleteat!(ARGS, 1)
	else
		parfile = "base/params.jl"
	end

	parfile
end

