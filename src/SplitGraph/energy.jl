export compute_energy

let n::Int64=0
	global increment_n() = (n+=1)
	global reset_n() = (n=0)
	global get_n() = n
end
let resolve::Bool = true
	global set_resolve(r) = (resolve = r)
	global get_resolve() = resolve
end

"""
"""
function compute_energy(conf::Array{Bool,1}, g::Graph)
	length(conf) != length(g.leaves) && error("`conf` and `g` do not have the same length")
	E = 0
	if length(g.leaves) + length(g.internals) == 1
		return E
	end
	@inbounds for (i,s) in enumerate(conf)
		if s
			for k1 in 1:g.K
				# Ancestors in tree k1
				a1 = g.leaves[i].anc[k1]
				# If ancestor is identical to leaf for given configuration, go up
				# ie go up to the first non trivial split
				while is_trivial_split(a1.conf, conf) && !a1.isroot
					a1 = a1.anc::SplitNode
				end
				for k2 in (k1+1):g.K
					# Same for
					a2 = g.leaves[i].anc[k2]
					while is_trivial_split(a2.conf, conf) && !a2.isroot
						a2 = a2.anc
					end
					if get_resolve() && !are_equal_with_resolution(g, a1.conf, a2.conf, conf, k1, k2)
						E += 1
					elseif !get_resolve() && !are_equal(a1.conf, a2.conf, conf)
						E += 1
					end
				end
			end
		end
	end
	return E
end

"""
	 are_equal(nconf1, nconf2, conf)

Are internal configurations `nconf1` and `nconf2` equal for leaf configuration `conf`?
"""
function are_equal(nconf1, nconf2, conf)
	_in = max(length(nconf1), length(nconf2)) > 25 ? insorted : in

	@inbounds for n1 in nconf1
		if conf[n1] && !_in(n1, nconf2)
			return false
		end
	end

	@inbounds for n2 in nconf2
		if conf[n2] && !_in(n2, nconf1)
			return false
		end
	end

	return true
end



"""
	are_equal_with_resolution(g, aconf1, aconf2, conf, k1, k2)
"""
function are_equal_with_resolution(g, aconf1, aconf2, conf, k1::Int, k2::Int)
	if are_equal(aconf1, aconf2, conf)
		return true
	elseif is_contained(aconf1, aconf2, conf) && are_equal_with_resolution(g, aconf1, aconf2, k2, conf)
		return true
	elseif is_contained(aconf2, aconf1, conf) && are_equal_with_resolution(g, aconf2, aconf1, k1, conf)
		return true
	end
	return false
end

"""
	are_equal_with_resolution(g, aconf1, aconf2, k2, conf)

For every leaf `n` in `a1.conf`, check if all ancestors of `n` in tree `k2` up to `a2`
  have a split that is contained in `a1.conf`, for `conf` as a leaves state.
  If so, the split `a1.conf` (for `conf`) can be transformed into a clade in the other
  tree `k2` by adding one internal node.

**Expects `is_contained(a1.conf, a2.conf, conf)` to return `true`.**
"""
function are_equal_with_resolution(g::SplitGraph.Graph, aconf1, aconf2, k2::Int, conf)
	@inbounds for i in aconf1
		if conf[i]
			a = g.leaves[i].anc[k2]
			while a.conf != aconf2
				if !is_contained(a.conf, aconf1, conf)
					return false
				end
				a = a.anc::SplitNode
			end
		end
	end
	return true
end

function is_trivial_split(nodeconf, conf)
	n = 0
	@inbounds for i in nodeconf
		if conf[i]
			n += 1
		end
	end
	return n < 2
end


"""
	is_contained(nconf1, nconf2, conf)

Is `nconf1` in `nconf2` for leaf configuration `conf`?
"""
function is_contained(nconf1, nconf2, conf)
	_in = max(length(nconf2)) > 25 ? insorted : in
	@inbounds for i in nconf1
		if conf[i] && !_in(i, nconf2)
			return false
		end
	end
	return true
end

"""
"""
function compute_F(conf::Array{Bool,1}, g::Graph, γ::Real)
	E = compute_energy(conf, g)
	return E + γ*(length(conf) - sum(conf))
end

"""
"""
function doMCMC(g::Graph, conf::Array{Bool,1}, M::Int64; T=1, γ=1)
	_conf = copy(conf)
	E = compute_energy(_conf, g)
	F = E + γ*(length(conf) - sum(conf))
	##
	# ee = zeros(Int,M+1)
	# ff = zeros(Float64,M+1)
	# ee[1] = E
	# ff[1] = F
	##
	Fmin = F
	oconf = [copy(_conf)]
	for m in 1:M
		E, F = mcmcstep!(_conf, g, F, T, γ)
		# ee[m+1] = E
		# ff[m+1] = F
		# If new minimum is found
		if F < Fmin
			Fmin = F
			oconf[1] .= _conf
			deleteat!(oconf, 2:length(oconf))
		end
		# If equal minimum is found
		if F == Fmin && !in(_conf, oconf) #mapreduce(x->x!=_conf, *, oconf)
			push!(oconf, copy(_conf))
		end
	end
	return oconf, _conf, Fmin
end

"""
"""
function mcmcstep!(conf, g, F, T, γ)
	i = rand(1:length(conf))
	conf[i] = !conf[i]
	Enew = compute_energy(conf, g)
	Fnew = Enew + γ*(length(conf) - sum(conf))
	if Fnew < F || exp(-(Fnew-F)/T) > rand()
		return Enew, Fnew
	else
		conf[i] = !conf[i]
		return (round(Int64, F-γ*(length(conf) - sum(conf))), F)
	end
end

"""
	sa_opt(g::Graph; Trange=1.:-0.01:0.1, γ=1.05, M=1000, rep=1, resolve=true)

Call `_sa_opt` repeatedly to find a set of optimal confs.
"""
function sa_opt(g::Graph; Trange=reverse(1e-3:1e-2:0.6), γ=2., M=10, rep=1, resolve=true)
	set_resolve(resolve)
	#
	oconf = Any[]
	F = Int64[]
	Fmin = Inf
	nfound = 0
	for r in 1:rep
		oconf_, F_ = _sa_opt(g, γ, Trange, M)
		Fm = minimum(F_)
		if Fm == Fmin
			append!(oconf, oconf_)
			append!(F, F_)
			nfound += 1
		elseif Fm < Fmin
			Fmin = Fm
			oconf = oconf_
			F = F_
			nfound = 1
		end
	end
	return unique(oconf), F, nfound
end

function _sa_opt(g::Graph, γ, Trange, M)
	reset_chance = 0.0
	conf = ones(Bool, length(g.leaves))
	oconf = [copy(conf)]
	F = Float64[Inf]
	Fmin = F[1]
	for T in Trange
		if rand() < reset_chance
			tmp_oconf, conf, fmin = doMCMC(g, oconf[rand(1:length(oconf))], M, T=T,γ=γ)
		else
			tmp_oconf, conf, fmin = doMCMC(g, conf, M, T=T,γ=γ)
		end
		append!(F,fmin)
		# If a better conf is found than all configurations in oconf
		# (which is the min of `f` from doMCMC), completely replace oconf
		if fmin < Fmin
			oconf = tmp_oconf
			Fmin = fmin
		# If equally good confs have been found
		elseif fmin == Fmin
			append!(oconf, tmp_oconf)
			oconf = unique(oconf)
		end
	end
	return oconf,F
end

"""
	count_mismatches(g::Graph)

Count the number of topological mismatches in `g`.
  Equivalent to `compute_energy(conf, g)` with `conf = ones(Bool)`.
"""
function count_mismatches(g::Graph)
	conf = ones(Bool, length(g.leaves))
	return compute_energy(conf, g)
end

"""
	count_mismatches(t::Vararg{Tree})
"""
function count_mismatches(trees::Vararg{Tree})
	treelist = [copy(t, TreeTools.EmptyData) for t in trees]
	mcc = naive_mccs(treelist)
	mcc_names = TreeKnit.name_mcc_clades!(treelist, mcc)
	for (i,t) in enumerate(treelist)
		TreeKnit.reduce_to_mcc!(t, mcc)
	end
	g = trees2graph(treelist)
	conf = ones(Bool, length(g.leaves))

	return compute_energy(conf, g)
end


