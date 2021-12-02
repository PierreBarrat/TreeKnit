function get_leave_order(tree, MCCs)

end



## BEFORE REMOVING `write_mccs!`:
## Check whether it's used in annotating auspice json files
# """
#     write_mccs!(trees::Dict, MCCs::Dict, key=:mcc_id)

# Write MCCs id to field `data.dat[key]` of tree nodes. Expect `trees` indexed by single segments, and `MCCs` indexed by pairs of segments.
# """
# function write_mccs!(trees::Dict, MCCs::Dict, key=:mcc_id; overwrite=false)
#     for ((i,j), mccs) in MCCs
#         k = Symbol(key,"_$(i)_$(j)")
#         write_mccs!(trees[i], mccs, k, overwrite=overwrite)
#         write_mccs!(trees[j], mccs, k, overwrite=overwrite)
#     end
# end
# """
#     write_mccs!(t::Tree, MCCs, key=:mcc_id)

# Write MCCs id to field `data.dat[key]` of tree nodes.
# """
# function write_mccs!(t::Tree{TreeTools.MiscData}, MCCs, key=:mcc_id; overwrite=false)
#     for (i,mcc) in enumerate(MCCs)
#         for label in mcc
#             t.lleaves[label].data.dat[key] = i
#         end
#         for n in Iterators.filter(n->!n.isleaf, values(t.lnodes))
#             if is_branch_in_mcc(n, mcc)
#                 if !overwrite && haskey(n.data.dat, key)
#                     error("Node $(n.label) already has an MCC attributed")
#                 end
#                 n.data.dat[key] = i
#             end
#         end
#     end
#     nothing
# end

"""
    is_branch_in_mccs(n::TreeNode, mccs::Array)


Is the branch from `n` to `n.anc` in an element of `mccs`?
"""
function is_branch_in_mccs(n::TreeNode, mccs::Dict)
    for mcc in values(mccs)
        if is_branch_in_mcc(n, mcc)
            return true
        end
    end
    return false
end
function is_branch_in_mccs(n::TreeNode, mccs)
    for mcc in mccs
        if is_branch_in_mcc(n, mcc)
            return true
        end
    end
    return false
end

"""
    is_branch_in_mcc(n::TreeNode, mcc::Array{<:AbstractString})

Is the branch from `n` to `n.anc` in `mcc`?
The clade defined by `n` has to intersect with `mcc`, and this intersection should be strictly smaller `mcc`.
"""
function is_branch_in_mcc(n::TreeNode, mcc::Array{<:AbstractString,1})
    # Simple check
    if n.isleaf
        return length(mcc) > 1 && in(n.label, mcc)
    end

    i = count(c -> c.isleaf && in(c.label, mcc), n)

    return (i > 0 && i < length(mcc))
end
"""
    find_mcc_with_branch(n::TreeNode, mccs::Dict)

Find the mcc to which the branch from `n` to `n.anc` belongs. If `mccs` is an array, return the pair `(index, value)`. If it is a dictionary, return the pair `(key, value)`. If no such mcc exists, return `nothing`.
Based on the same idea that `is_branch_in_mcc`.
"""
function find_mcc_with_branch(n::TreeNode, mccs::Dict)
    cl = [x.label for x in POTleaves(n)]
    for (key,mcc) in mccs
        if !isempty(intersect(cl, mcc)) && !isempty(setdiff(mcc, intersect(cl, mcc)))
            return (key, mcc)
        end
    end
    return nothing
end
function find_mcc_with_branch(n::TreeNode, mccs::Array)
    cl = [x.label for x in POTleaves(n)]
    for (i,mcc) in enumerate(mccs)
        if !isempty(intersect(cl, mcc)) && !isempty(setdiff(mcc, intersect(cl, mcc)))
            return (i,mcc)
        end
    end
    return nothing
end

"""
    is_linked_pair(n1, n2, mccs)
    is_linked_pair(n1::T, n2::T, mccs::Dict{Any,Array{T,1}}) where T
    is_linked_pair(n1::T, n2::T, mccs::Array{Array{T,1},1}) where T

Can I join `n1` and `n2` through common branches only? Equivalent to: is there an `m` in `mccs` such that `in(n1,m) && in(n2,m)`?
"""
function is_linked_pair(n1::T, n2::T, mccs::Dict{Any,Array{T,1}}) where T
    for mcc in values(mccs)
        if in(n1, mcc)
            return in(n2, mcc)
        elseif in(n2, mcc)
            return false
        end
    end
    return false
end
function is_linked_pair(n1, n2, mccs)
    for mcc in values(mccs)
        if in(n1, mcc)
            return in(n2, mcc)
        elseif in(n2, mcc)
            return false
        end
    end
    return false
end
function is_linked_pair(n1::T, n2::T, mccs::Array{Array{T,1},1}) where T
    for mcc in mccs
        if in(n1, mcc)
            return in(n2, mcc)
        elseif in(n2, mcc)
            return false
        end
    end
    return false
end

"""
    find_mcc_with_node(n::String, mccs::Array{Array{<:AbstractString,1},1})

Find MCC to which `n` belongs.
"""
function find_mcc_with_node(n::String, mccs)
    for m in mccs
        if in(n, m)
            return m
        end
    end
    return nothing
end
find_mcc_with_node(n::TreeNode, mccs) = find_mcc_with_node(n.label, mccs)
find_mcc_with_node(n, mccs) = find_mcc_with_node(n.label, mccs)



"""
    fraction_of_common_pairs(MCC1, MCC2)
    fraction_of_common_pairs(MCC1, MCC2, leaves; linked_only=false)

Fraction of pairs of leaves in `leaves` that are predicted to be in the same MCC in both decompositions `MCC1` and `MCC2`. If `leaves` is not given, the common leaves of `MCC1` and `MCC2` are used.
If `linked_only`, only consider pairs that are linked in one or the other sets of MCCs (normalization is adapted accordingly)
"""
function fraction_of_common_pairs(MCC1, MCC2)
    leaves = unique(intersect(union(MCC1...), union(MCC2...)))
    return fraction_of_common_pairs(MCC1, MCC2, leaves)
end
function fraction_of_common_pairs(MCC1, MCC2, leaves; linked_only=false)
    n = 0
    Z = 0
    for i in 1:length(leaves), j in (i+1):length(leaves)
        if !linked_only
            TreeKnit.is_linked_pair(leaves[i], leaves[j], MCC1) == TreeKnit.is_linked_pair(leaves[i], leaves[j], MCC2) && (n+=1)
            Z += 1
        else
            if TreeKnit.is_linked_pair(leaves[i], leaves[j], MCC1)
                Z += 1
                TreeKnit.is_linked_pair(leaves[i], leaves[j], MCC2) && (n+=1)
            elseif TreeKnit.is_linked_pair(leaves[i], leaves[j], MCC2)
                Z += 1
                TreeKnit.is_linked_pair(leaves[i], leaves[j], MCC1) && (n+=1)
            end
        end
    end
    return n / Z
end


function mcc_branch_length(t::Tree, mcc)
	mcc_root = lca(t, mcc)
	if mcc_root.isroot
		return missing, missing
	else
		bl_low = 0.
		visited = []
		for leaf in mcc
			n = t.lleaves[leaf]
			while n != mcc_root && !in(n.label, visited)
				n.isroot && error("Reached root.")
				bl_low += n.tau
				push!(visited, n.label)
				n = n.anc
			end
		end
	end

	bl_high = bl_low + mcc_root.tau
	return bl_low, bl_high
end








