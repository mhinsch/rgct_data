# this package provides some nice convenience syntax 
# for parameters
using Parameters

const VF = Vector{Float64}

"Simulation parameters"
@with_kw struct Params
	"rng seed for the simulation"
	rand_seed_sim	:: Int		= 113
	"rng seed for world creation"
	rand_seed_world	:: Int		= 123

	"number of cities"
	n_cities		:: Int		= 300
	"maximum distance for link generation"
	link_thresh		:: Float64	= 0.1

	"number of departures per time step"
	rate_dep	 	:: Float64	= 20
	"number of exits"
	n_exits			:: Int		= 10
	"distribute exits evenly?"
	regular_exits	:: Bool		= false
	"number of starting positions"
	n_entries		:: Int		= 5
	"distribute entries evenly?"
	regular_entries	:: Bool		= false
	"where to start connecting cities to exits"
	exit_dist		:: Float64	= 0.5
	"where to stop connecting cities to entries"
	entry_dist		:: Float64	= 0.1
	"how many of the closest cities to connect to an entry"
	n_nearest_entry	:: Int = 3
	"how many of the closest cities to connect to an exit"
	n_nearest_exit	:: Int = 0
	"quality of entries"
	qual_entry		:: Float64	= 0.0
	"resources at entries"
	res_entry		:: Float64	= 0.0
	"quality of exits"
	qual_exit		:: Float64	= 1
	"resources at exits"
	res_exit		:: Float64	= 1

	"coordinates of high risk obstacle (rectangle)"
	obstacle		:: VF		= [0.4, 0.3, 0.6, 0.7]

	# scale >= 1.0 required, otherwise path finding breaks
	"how friction scales with distance"
	dist_scale		:: VF		= [1.0, 10.0]
	"stochastic range of friction"
	frict_range		:: Float64	= 0.5
	"risk on ordinary links"
	risk_normal		:: Float64	= 0.002
	"risk on high-risk links"
	risk_high		:: Float64	= 0.1
	"expected risk for newly discovered links"
	risk_exp		:: Float64	= 0.01
	"scale between 'safe' and 'survivable'"
	risk_scale		:: Float64	= 10.0

	"number of contacts when entering"
	n_ini_contacts	:: Int		= 10
	"amount of capital when entering"
	ini_capital 	:: Float64 	= 2000.0
	"set of always unknown cities"
	p_unknown_city	:: Float64 = 0.0
	"set of always unknown links"
	p_unknown_link	:: Float64 = 0.0
	"prob. to know a target when entering"
	p_know_target	:: Float64	= 0.0
	"prob. to know a city (per city)"
	p_know_city		:: Float64	= 0.0
	"prob. to know a link (per link)"
	p_know_link		:: Float64	= 0.0
	"efficiency of exploration for initial knowledge"
	speed_expl_ini	:: Float64	= 1.0

	"intercept of risk scoring function"
	risk_i			:: Float64	= -7.64
	"slope of risk scoring function"
	risk_s			:: Float64	= 0.16
	"sd of intercept of risk scoring function"
	risk_sd_i		:: Float64	= 4.68
	"sd of slope of risk scoring function"
	risk_sd_s		:: Float64	= 0.08
	"covariance between intercept and slope of risk scoring function"
	risk_cov_i_s	:: Float64	= -0.337

	"rate at which agents plan their movement after receiving info"
	rate_plan		:: Float64	= 100.0

	"expected resources at newly found city"
	res_exp			:: Float64	= 0.5
	"expected quality at newly found city"
	qual_exp		:: Float64	= 0.5
	"expected friction for newly found link"
	frict_exp		:: VF		= [1.25, 12.5]
	"prob. to find links when exploring"
	p_find_links	:: Float64	= 0.5
	"trust in detected friction/risk for discovered links"
	trust_found_links :: Float64 = 0.5
	"prob. to find destinations of found links"
	p_find_dests	:: Float64	= 0.3
	"trust in information collected while travelling"
	trust_travelled	:: Float64	= 0.8
	"efficiency of exploration while staying"
	speed_expl_stay :: Float64	= 1.0
	"efficiency  of exploration while moving"
	speed_expl_move :: Float64	= 1.0
	"rate (frequency) of exploration while staying"
	rate_explore_stay :: Float64	= 1.0

	"probability to notice if contact died"
	p_notice_death_c :: Float64	= 0.3
	"probability to notice if migrant on same link died"
	p_notice_death_o :: Float64 = 0.1
	"effect on risk perception of contact death"
	speed_risk_indir :: Float64 = 0.1
	"effect on risk perception of observed death"
	speed_risk_obs	:: Float64	= 0.1
	"speed of learning about risk by exploration (relative to other properties)"
	speed_expl_risk	:: Float64	= 1.0


	"rate of costs applying while staying"
	rate_costs_stay	:: Float64	= 1.0
	"resource costs of staying"
	costs_stay		:: Float64	= 1.0
	"benefit of resource uptake"
	ben_resources	:: Float64	= 5.0
	"resource costs of moving"
	costs_move		:: Float64	= 2.0
	"when to start saving up capital"
	save_thresh		:: Float64	= 100.0
	"min income required to start saving"
	save_income		:: Float64	= 1.0
	"movement speed"
	move_speed		:: Float64	= 0.5
	"base movement rate"
	move_rate		:: Float64	= 0.0

	"elasticity of traffic counter"
	ret_traffic		:: Float64	= 0.8
	"effect of traffic on current quality"
	weight_traffic	:: Float64	= 0.001

	"effect of proximity to exit on perceived quality"
	qual_weight_x	:: Float64	= 0.25
	"effect of resources on perceived quality"
	qual_weight_res	:: Float64 	= 0.1
	"tolerance towards friction when looking for local improvement"
	qual_tol_frict	:: Float64	= 2.0
	"bias of choice towards higher quality"
	qual_bias		:: Float64	= 1.0
	"effect of low location quality on path costs"
	path_penalty_loc :: Float64 = 1.0
	"effect of risk on path costs"
	path_penalty_risk:: Float64 = 5

	"prob. to add an agent to contacts"
	p_keep_contact 	:: Float64 	= 0.1
	"prob. to lose contact"
	p_drop_contact	:: Float64	= 0.1
	"prob. to exchange info with contacts"
	p_info_contacts	:: Float64	= 0.1
	"prob. to transfer info item"
	p_transfer_info	:: Float64	= 0.1
	"maximum number of contacts"
	n_contacts_max	:: Int		= 50
	"learning speed of arrived agents"
	arr_learn		:: Float64	= 0.0
	"change doubt into belief"
	convince		:: Float64	= 0.5
	"change belief into other belief"
	convert			:: Float64	= 0.1
	"change belief into doubt"
	confuse			:: Float64	= 0.3
	"stochastic error when transmitting information"
	error			:: Float64 	= 0.1
	"stochastic error when transmitting risk information"
	error_risk		:: Float64 	= 0.01
	"stochastic error when transmitting friction information"
	error_frict		:: Float64 	= 0.5
	"weight of opinion of arrived agents"
	weight_arr		:: Float64	= 1.0
end

