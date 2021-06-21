#!/usr/bin/env julia

push!(LOAD_PATH, replace(pwd(), "/gui" => ""))

using Params2Args

pfile = ARGS[1]

include(pfile)

println(fields_as_cmdl(Params(), ARGS[2:end]))

