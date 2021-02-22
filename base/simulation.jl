using SimpleAgentEvents

include("model.jl")


mutable struct Simulation{PAR}
	model :: Model
	par :: PAR
end

