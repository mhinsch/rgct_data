using Util
using Beliefs

include("world_util.jl")


# a piece of knowledge an agent has about a location
mutable struct InfoLocationT{L}
	id :: Int
	pos :: Pos
	links :: Vector{L}

	# property values the agent expects
	resources :: TrustedF
	quality :: TrustedF
end

mutable struct InfoLink
	id :: Int
	l1 :: InfoLocationT{InfoLink}
	l2 :: InfoLocationT{InfoLink}

	friction :: TrustedF
	risk :: TrustedF
end

const InfoLocation = InfoLocationT{InfoLink}

const Unknown = InfoLocation(0, Nowhere, [], TrustedF(0.0), TrustedF(0.0))
const UnknownLink = InfoLink(0, Unknown, Unknown, TrustedF(0.0), TrustedF(0.0))


#resources(l :: InfoLocation) = l.resources.value
#quality(l :: InfoLocation) = l.quality.value
@inline friction(l :: InfoLink) = l.friction.value
@inline risk(l :: InfoLink) = l.risk.value


@inline otherside(link, loc) = loc == link.l1 ? link.l2 : link.l1

# no check for validity etc.
@inline add_link!(loc, link) = push!(loc.links, link)


# migrants
mutable struct AgentT{LOC, LINK}
	# current real position
	loc :: LOC
	link :: LINK
	# what it thinks it knows about the world
	n_locs :: Int
	info_loc :: Vector{InfoLocation}
	info_target :: Vector{InfoLocation}
	pref_target :: LOC
	n_links :: Int
	info_link :: Vector{InfoLink}
	risk_s :: Float64
	risk_i :: Float64
	plan :: Vector{InfoLocation}
	path :: Vector{LOC}
	out_of_date :: Float64
	# abstract capital, includes time & money
	capital :: Float64
	# people at home & in target country, other migrants
	contacts :: Vector{AgentT{LOC, LINK}}
	planned :: Int
	max_cost_delta :: Float64
end

@inline knows_target(agent) = length(agent.info_target) > 0 
@inline target(agent) = knows_target(agent) ? agent.info_target[1] : Unknown

@inline arrived(agent) = agent.loc.typ == EXIT


function add_info!(agent, info :: InfoLocation, typ = STD) 
	@assert agent.info_loc[info.id] == Unknown
	agent.n_locs += 1
	agent.info_loc[info.id] = info
	if typ == EXIT
		push!(agent.info_target, info)
	end
end

function add_info!(agent, info :: InfoLink) 
	@assert agent.info_link[info.id] == UnknownLink
	agent.n_links += 1
	agent.info_link[info.id] = info
end

function add_contact!(agent, a)
	if a in agent.contacts
		return
	end

	push!(agent.contacts, a)
end


@enum LOC_TYPE STD=1 ENTRY EXIT

mutable struct LocationT{L}
	id :: Int
	typ :: LOC_TYPE
	pos :: Pos

	links :: Vector{L}
	people :: Vector{AgentT{LocationT{L}}}

	count :: Int
	cur_count :: Int
	traffic :: Float64

	resources :: Float64
	quality :: Float64
end


@inline distance(l1, l2) = distance(l1.pos, l2.pos)

@enum LINK_TYPE FAST=1 SLOW

mutable struct Link
	id :: Int
	typ :: LINK_TYPE

	l1 :: LocationT{Link}
	l2 :: LocationT{Link}
	people :: Vector{AgentT{LocationT{Link}}}
	count :: Int
	count_deaths :: Int

	risk :: Float64
	friction :: Float64
	distance :: Float64
end


Link(id, t, l1, l2) = Link(id, t, l1, l2, [], 0, 0, 0, 0, 0)

const Location = LocationT{Link}
Location(p :: Pos, t, i) = Location(i, t, p, [], [], 0, 0, 0.0, 0.0, 0.0)
const NoLoc = Location(Nowhere, STD, 0)

const NoLink = Link(0, FAST, NoLoc, NoLoc)

const Agent = AgentT{Location, Link}

Agent(loc::Location, c :: Float64) = Agent(loc, NoLink, 0, [], [], NoLoc, 0, [], 1.0, 0.0, [], [loc], 1.0, c, [], 0, 0.0)

@inline in_transit(a :: Agent) = a.link != NoLink

@inline function start_transit!(a :: Agent, l :: Link)
	a.link = l
end

@inline function end_transit!(a :: Agent, l :: Location)
	a.link = NoLink
	a.loc = l
	push!(a.path, a.loc)
end

@inline position(agent) = in_transit(agent) ? mid(agent.link.l1.pos, agent.link.l2.pos) : agent.loc.pos

@inline dead(a) = !in_transit(a) && (a.loc == NoLoc)

function set_dead!(a)
	a.loc = NoLoc
	a.link = NoLink
end

@inline active(agent) = !dead(agent) && !arrived(agent)


# get the agent's info on a location
@inline info(agent, l::Location) = agent.info_loc[l.id]
# get the agent's info on its current location
@inline info_current(agent) = info(agent, agent.loc)
# get the agent's info on a link
@inline info(agent, l::Link) = agent.info_link[l.id]

@inline known(l::InfoLocation) = l != Unknown
@inline known(l::InfoLink) = l != UnknownLink

# get the agent's info on a location
@inline knows(agent, l::Location) = known(info(agent, l))
# get the agent's info on a link
@inline knows(agent, l::Link) = known(info(agent, l))

function find_link(from, to)
	for l in from.links
		if otherside(l, from) == to
			return l
		end
	end

	nothing
end


mutable struct World
	cities :: Vector{Location}
	links :: Vector{Link}
	entries :: Vector{Location}
	exits :: Vector{Location}
end

World() = World([], [], [], [])


remove_agent!(l, agent) = drop!(l.people, agent)

function add_agent!(loc::Location, agent::Agent) 
	push!(loc.people, agent)
	loc.count += 1
	loc.cur_count += 1
end

function add_agent!(link::Link, agent::Agent) 
	push!(link.people, agent)
	link.count += 1
end

remove_agent!(world::World, agent) = remove_agent!((in_transit(agent) ? agent.link : agent.loc), agent)


@inline info2real(l::InfoLocation, world) = world.cities[l.id]
@inline info2real(l::InfoLink, world) = world.links[l.id]


# connect loc and link (if not already connected)
function connect!(loc :: InfoLocation, link :: InfoLink)
	# add location to link
	if link.l1 != loc && link.l2 != loc
		# link not connected yet, should have free slot
		if !known(link.l1)
			link.l1 = loc
		elseif !known(link.l2)
			link.l2 = loc
		else
			error("Error: Trying to connect a fully connected link!")
		end
	end

	# add link to location
	if ! (link in loc.links)
		add_link!(loc, link)
	end
end


@inline dist_eucl(x1, y1, x2, y2) = sqrt((x2-x1)^2 + (y2-y1)^2)


# TODO: should accuracy be discounted by trust value?

@inline accuracy(li::InfoLocation, lr::Location) = 
	1.0 - dist_eucl(li.quality.value, li.resources.value, lr.quality, lr.resources)/sqrt(2.0)

@inline accuracy(li::InfoLink, lr::Link) = 1.0 - sqrt(
	((li.friction.value - lr.friction)/lr.distance)^2 / 2 + 
	(li.risk.value - lr.risk)^2 / 2)


function dump(file, agent)
	dont_print = [:loc, :link, :pref_target]
	for n in fieldnames(typeof(agent))
		if n in dont_print || typeof(getproperty(agent, n)) <: Array
			continue
		end
		println(file, string(n), ": ", getproperty(agent, n))
		println(string(n), ": ", getproperty(agent, n))
	end

	println(file, "loc:\t", agent.loc.id)
	println(file, "link:\t", agent.link.id)
	println(file, "pref:\t", agent.pref_target.id)
	println(file, "info_loc:")
	for l in agent.info_loc
		if !known(l)
			println(file, "\tUNKNOWN")
			continue
		end
		println(file, "\t", l.id, "\t", l.quality.value, "\t", l.quality.trust, 
			"\t", l.resources.value, "\t", l.resources.trust)
	end
	println(file, "info_link")
	for l in agent.info_link
		if !known(l)
			println(file, "\tUNKNOWN")
			continue
		end
		println(file, "\t", l.id, "\t", l.friction.value, "\t", l.friction.trust,
			"\t", l.risk.value, "\t", l.risk.trust)
	end
end

