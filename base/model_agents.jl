
include("world_path_util.jl")


# *********
# decisions
# *********

# quality, resources
@inline qual(quality, res, weight) = quality * (1 - weight) + res * weight

@inline qual(quality::T, res::T, weight) where {T<:Trusted} = 
	qual(discounted(quality), discounted(res), weight)


# costs from quality [1:1+p]   (1/penalty + 1) / (1/penalty + quality)
@inline costs_qual(penalty, quality) = (1.0 + penalty) / (1.0 + penalty*quality)

# costs including friction and safety
@inline costs_qual_sf(frict, c_qual, penalty, safe) = 
	frict * c_qual + penalty * (1-safe)


@inline disc_friction(frict) = 2 * frict.value - discounted(frict)


"Quality of location `loc` for global planning (no effect of x)."
@inline quality(loc, par) = qual(loc.quality, loc.resources, par.qual_weight_res) # [0:1]

# used for model and GUI
@inline costs_quality(loc, par)  = costs_qual(par.path_penalty_loc, quality(loc, par)) # [1:1+pp]


@inline function safety_score(agent, link, par) # [0:1]
	# convert to prob. of safety
	likely_safe = link.risk.trust * (1.0 - link.risk.value)^par.risk_scale
	# parameterised to percentage 
	ex = exp(agent.risk_i + agent.risk_s * likely_safe * 100.0)

	ex / (1.0 + ex)
end

# [frict : 2*frict*(1+pen) + pen_r]
@inline function costs_quality(link :: InfoLink, loc :: InfoLocation, agent, par)
	costs_qual_sf(disc_friction(link.friction), costs_quality(loc, par), 
		par.path_penalty_risk, safety_score(agent, link, par))
end

"Movement costs from `l1` to `l2`, taking into account `l2`'s quality."
@inline function costs_quality(l1::InfoLocation, l2::InfoLocation, agent, par)
	link = find_link(l1, l2)
	costs_quality(link, l2, agent, par)
end

"Quality when looking for local improvement."
@inline function local_quality(loc :: InfoLocation, par)
	par.qual_weight_x * loc.pos.x + quality(loc, par)
end


function make_plan!(agent, par)
	# no plan if we don't know any targets
	if isempty(agent.info_target)
		agent.plan = []
		return
	end

	# get the least cost plan
	best_plan, count, costs = Pathfinding.path_Astar(info_current(agent), agent.info_target, 
			(l1, l2)->costs_quality(l1, l2, agent, par), path_costs_estimate, each_neighbour)
	
	# no path found
	if isempty(best_plan)
		agent.plan = []
		return
	end

	info_pref_target = info(agent, agent.pref_target)
	# we don't know our pref target anyway, so take the best route
	if info_pref_target == Unknown ||
		# pref < 1 means we alway select best
		par.pref_target <= 1.0 ||
		# we know our pref target, maybe the best route goes there
		best_plan[1] == info_pref_target
		agent.plan = best_plan
		return
	end

	# we know our pref target, but the best plan doesn't go there
	# let's see how good the route to the pref target is

	pref_plan, count, pref_costs = 
		Pathfinding.path_Astar(info_current(agent), info_pref_target, 
			(l1, l2)->costs_quality(l1, l2, agent, par), path_costs_estimate, each_neighbour)
	
	if isempty(pref_plan) || pref_costs > par.pref_target * costs
		agent.plan = best_plan
	else
		agent.plan = pref_plan
	end

	return
end



# ***********
# exploration
# ***********

function discover_if_unknown!(agent, loc :: Location, par)
	if knows(agent, loc)
		return
	end

	discover!(agent, loc, par)
end

# add new location to agent (based on world info)
# connect to existing links
function discover!(agent, loc :: Location, par)
	# agents start off with expected values
	inf = InfoLocation(loc.id, loc.pos, [], TrustedF(par.res_exp), TrustedF(par.qual_exp))
	# add location info to agent
	add_info!(agent, inf, loc.typ)
	# connect existing link infos
	for link in loc.links
		info_link = info(agent, link)

		# links to exit are always known
		if !known(info_link)
			if loc.typ != EXIT
				lo = otherside(link, loc)
				if lo.typ == EXIT && knows(agent, lo)
					discover!(agent, link, loc, par)
				end
			end
		# connect known links
		else				
			connect!(inf, info_link)
		end
	end

	inf	
end	


# add new link to agent (based on world info)
# connect to existing location
function discover!(agent, link :: Link, from :: Location, par)
	info_from = info(agent, from)
	@assert known(info_from)
	info_to = info(agent, otherside(link, from))
	frict = link.distance * par.frict_exp[Int(link.typ)]
	@assert frict > 0
	risk = par.risk_exp
	info_link = InfoLink(link.id, info_from, info_to, TrustedF(frict), TrustedF(risk))
	add_info!(agent, info_link)
	# TODO lots of redundancy, possibly join/extend
	connect!(info_from, info_link)
	if known(info_to)
		connect!(info_to, info_link)
	end

	info_link	
end


#function current_quality(loc :: Location, par)  
#	(loc.quality + loc.traffic * par.weight_traffic) / (1.0 + loc.traffic * par.weight_traffic)
#end

function explore_at!(agent, world, loc :: Location, speed, allow_indirect, par)
	# knowledge
	inf = info(agent, loc)
	
	if !known(inf)
		inf = discover!(agent, loc, par)
	end

	# gain information on local properties
	# stochasticity?
	inf.resources = update(inf.resources, loc.resources, speed)
	inf.quality = update(inf.quality, loc.quality, speed)
	#inf.quality = update(inf.quality, current_quality(loc, par), speed)

	# only location, no links, done
	if ! allow_indirect
		return inf, loc
	end

	# gain info on links and linked locations
	
	for link in loc.links
		info_link = info(agent, link)

		if !known(info_link) && rand() < par.p_find_links
			info_link = discover!(agent, link, loc, par)

			#info_link.friction = TrustedF(link.friction, par.trust_found_links)
			info_link.friction = update(info_link.friction, link.friction, speed)
			info_link.risk = update(info_link.risk, link.risk, speed * par.speed_expl_risk)
			
			# no info, but position is known
			explore_at!(agent, world, otherside(link, loc), 0.0, false, par)
		end

		# we might get info on connected location
		if known(info_link) && rand() < par.p_find_dests
			explore_at!(agent, world, otherside(link, loc), 0.5 * speed, false, par)
		end
	end

	inf, loc
end


function explore_at!(agent, world, link :: Link, from :: Location, speed, par)
	# knowledge
	inf = info(agent, link)

	if !known(inf)
		inf = discover!(agent, link, from, par)
	end

	# gain information on local properties
	inf.friction = update(inf.friction, link.friction, speed)
	inf.risk = update(inf.risk, link.risk, speed * par.speed_expl_risk)

	inf, link
end

# ********************
# information exchange
# ********************


function loc_belief_error(v::TrustedF, par)
	TrustedF(
		limit(0.0, v.value + unf_delta(par.error), 1.0),
		limit(0.000001, v.trust + unf_delta(par.error), 0.99999))
end

function link_frict_belief_error(v::TrustedF, par)
	TrustedF(
		max(0.0, v.value + unf_delta(par.error_frict)),
		limit(0.000001, v.trust + unf_delta(par.error), 0.99999))
end

function link_risk_belief_error(v::TrustedF, par)
	TrustedF(
	# potentially use separate error
		limit(0.0, v.value + unf_delta(par.error_risk), 1.0),
		limit(0.000001, v.trust + unf_delta(par.error), 0.99999))
end


function exchange_loc_info(loc, info1, info2, a1, a2, p1, p2, par)
	# neither agent knows anything
	if !known(info1) && !known(info2)
		return	
	end
	
	if !known(info1)
		info1 = discover!(a1, loc, par)
	elseif !known(info2) && !arrived(a2)
		info2 = discover!(a2, loc, par)
	end

	# both have knowledge at l, compare by trust and transfer accordingly
	if known(info1) && known(info2)
		res1, res2 = 
			exchange_beliefs(info1.resources, info2.resources, x->loc_belief_error(x, par), p1, p2)
		qual1, qual2 = 
			exchange_beliefs(info1.quality, info2.quality, x->loc_belief_error(x, par), p1, p2)
		info1.resources = res1
		info1.quality = qual1
		# only a2 can have arrived
		if !arrived(a2) 
			info2.resources = res2
			info2.quality = qual2
		end
	end
end


function exchange_link_info(link, info1, info2, a1, a2, p1, p2, par)
	# neither agent knows anything
	if !known(info1) && !known(info2)
		return
	end

	# only one agent knows the link
	if !known(info1)
		if knows(a1, link.l1) && knows(a1, link.l2)
			info1 = discover!(a1, link, link.l1, par)
		end
	elseif !known(info2) && !arrived(a2)
		if knows(a2, link.l1) && knows(a2, link.l2)
			info2 = discover!(a2, link, link.l1, par)
		end
	end
	
	# both have knowledge at l, compare by trust and transfer accordingly
	if known(info1) && known(info2)
		frict1, frict2 = 
			exchange_beliefs(info1.friction, info2.friction, x->link_frict_belief_error(x, par), p1, p2)
		risk1, risk2 = 
			exchange_beliefs(info1.risk, info2.risk, x->link_risk_belief_error(x, par), p1, p2)
		info1.friction = frict1
		# TODO find a better solution
		# really ugly but necessary for now
		info1.risk = TrustedF(limit(0.0, risk1.value, 1.0), risk1.trust)

		if !arrived(a2)
			info2.friction = frict2
			info2.risk = TrustedF(limit(0.0, risk2.value, 1.0), risk2.trust)
		end
	end
end


function exchange_info!(a1::Agent, a2::Agent, world::World, par)
	p2 = BeliefPars(par.convince, par.convert, par.confuse)
	# values a1 experiences, have to be adjusted if a2 has already arrived
	p1 = if arrived(a2)
			BeliefPars(par.convince^(1.0/par.weight_arr), par.convert^(1.0/par.weight_arr), par.confuse)
		else
			p2
		end

	for l in eachindex(a1.info_loc)
		if rand() > par.p_transfer_info
			continue
		end
		exchange_loc_info(world.cities[l], a1.info_loc[l], a2.info_loc[l], a1, a2, p1, p2, par)
	end

	for l in eachindex(a1.info_link)
		if rand() > par.p_transfer_info
			continue
		end
		exchange_link_info(world.links[l], a1.info_link[l], a2.info_link[l], a1, a2, p1, p2, par)
	end

	a1.out_of_date = 1.0
	if ! arrived(a2)
		a2.out_of_date = 1.0
	end
end


function update_risk_info!(agent, link, p, speed)
	infol = info(agent, link)

	# death registers, changes risk perception
	if known(infol) && rand() < p
		infol.risk = update(infol.risk, 1.0, speed)
		return true
	end

	return false
end


function learn_death_contact!(agent, dead, par)
	ret = false

	if (i = findfirst(isequal(dead), agent.contacts)) != nothing
		drop_at!(agent.contacts, i)
		ret = true
	end

	# death registers, changes risk perception
	if update_risk_info!(agent, dead.link, par.p_notice_death_c, par.speed_risk_indir)
		ret = true
	end

	ret
end


function learn_death_observed!(agent, dead, par)
	@assert dead.link == agent.link

	# death registers, changes risk perception
	if update_risk_info!(agent, dead.link, par.p_notice_death_o, par.speed_risk_obs)
		return true
	end

	false
end


maxed(agent, par) = length(agent.contacts) >= par.n_contacts_max

# *********************
# event functions/rates
# *********************

function rate_move(agent, par)
	loc = info_current(agent)

	if agent.capital < par.save_thresh && income(agent.loc, par) > par.save_income
		return 0.0
	end

	# we've made a decision and we've got enough money, let's go
	1.0
end


# same as ML3
rate_transit(agent, par) = par.move_rate + par.move_speed / agent.link.friction

# link risk is probability to die during transit, translate to rate
rate_mort(agent, par) = rate_transit(agent, par) * agent.link.risk / (1.0 - agent.link.risk)

rate_contacts(agent, par) = (length(agent.loc.people)-1) * par.p_keep_contact

rate_drop_contacts(agent, par) = length(agent.contacts) * par.p_drop_contact

rate_talk(agent, par) = length(agent.contacts) * par.p_info_contacts

rate_plan(agent, par) = agent.out_of_date * par.rate_plan



income(loc, par) = par.ben_resources * loc.resources - par.costs_stay

function costs_stay!(agent, par)
	agent.capital += income(agent.loc, par)
	[agent]
end


function plan_costs!(agent, par)
	make_plan!(agent, par)

	agent.out_of_date = 0.0

	if agent.plan != []
		return [agent]
	end

	# *** empty plan
	
	loc = info_current(agent)

	if length(loc.links) == 0
		return [agent]
	end

	quals = Float64[]
	sizehint!(quals, length(loc.links)+1)
	prev = 0.0

	for l in loc.links
		other = otherside(l, loc)

		q = if known(other)
				local_quality(other, par) * 
					par.qual_tol_frict / (par.qual_tol_frict + disc_friction(l.friction)) *
					safety_score(agent, l, par)
			else
				0.0		# Unknown has q<0 since Nowhere == (-1.0, -1.0)
			end

		push!(quals, q^par.qual_bias + prev)
		prev = quals[end]
	end

	# add current location, might be best option
	q = local_quality(loc, par)
	push!(quals, q^par.qual_bias + prev)

	best = length(quals)
	if quals[end] > 0.0
		r = rand() * quals[end]
		best = findfirst(x -> x>r, quals)
	end

	if best < length(quals)
		# go to best neighbouring location 
		agent.plan = [otherside(loc.links[best], loc)]
	end

	# plan == [] for staying

	[agent]
end


# explore while staying at a location
function explore_stay!(agent, world, par)
	explore_at!(agent, world, agent.loc, par.speed_expl_stay, true, par)

	agent.out_of_date = 1.0

	[agent]
end


function meet_locally!(agent, world, par)
	@assert ! arrived(agent)
	pop = agent.loc.people

	# with rescheduling this should not happen
	@assert length(pop) > 1

	while (a = rand(pop)) == agent end

	add_contact!(agent, a)
	if !maxed(a, par)
		add_contact!(a, agent)
	end

	exchange_info!(agent, a, world, par)

	[agent, a]
end


function drop_contact!(agent, par)
	drop_at!(agent.contacts, rand(1:length(agent.contacts)))

	[agent]
end


function talk_once!(agent, world, par)
	@assert ! arrived(agent)
	other = rand(agent.contacts)

	if dead(other)
		drop!(agent.contacts, other)
		return [agent]
	end

	exchange_info!(agent, other, world, par)

	(arrived(other) ? [agent] : [agent, other])
end


function costs_move!(agent, link :: Link, par)
	agent.capital -= par.costs_move * link.friction

	[agent]
end


function start_move!(agent, world, par)
	@assert ! dead(agent)
	@assert ! arrived(agent)

	next = info2real(agent.plan[end], world)
	link = find_link(agent.loc, next)

	if length(agent.plan) > 1
		agent.planned += 1
	end

	costs_move!(agent, link, par)

	remove_agent!(agent.loc, agent)
	add_agent!(link, agent)
	start_transit!(agent, link)
	
	# link exploration is a consequence of direct experience, so
	# it always happens
	explore_at!(agent, world, link, agent.loc, par.speed_expl_move, par)

	[agent; agent.loc.people]
end


function finish_move!(agent, world, par)
	next = info2real(agent.plan[end], world)
	pop!(agent.plan)

	remove_agent!(agent.link, agent)
	end_transit!(agent, next)
	add_agent!(next, agent)

	if arrived(agent)
		return typeof(agent)[]
	end

	next.people
end

