using SimpleAgentEvents

include("model.jl")


struct Simulation{PAR}
	model :: Model
	par :: PAR
end


