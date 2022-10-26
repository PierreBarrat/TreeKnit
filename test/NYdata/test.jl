using Test
using TreeTools
using TreeKnit
using TreeKnit.MTK

MCCs_ref = [
	["A/NewYork/105/2002"],
	["A/NewYork/177/1999"],
	["A/NewYork/137/1999", "A/NewYork/138/1999"],
	["A/NewYork/52/2004", "A/NewYork/59/2003"],
	["A/NewYork/198/2003", "A/NewYork/199/2003", "A/NewYork/32/2003"],
	["A/NewYork/10/2004", "A/NewYork/11/2003", "A/NewYork/12/2003", "A/NewYork/13/2003", "A/NewYork/14/2003", "A/NewYork/15/2003", "A/NewYork/16/2003", "A/NewYork/17/2003", "A/NewYork/18/2003", "A/NewYork/19/2003", "A/NewYork/2/2003", "A/NewYork/21/2003", "A/NewYork/22/2003", "A/NewYork/23/2003", "A/NewYork/24/2003", "A/NewYork/25/2003", "A/NewYork/26/2003", "A/NewYork/27/2003", "A/NewYork/28/2003", "A/NewYork/29/2003", "A/NewYork/30/2003", "A/NewYork/31/2004", "A/NewYork/33/2004", "A/NewYork/34/2003", "A/NewYork/35/2003", "A/NewYork/36/2003", "A/NewYork/38/2003", "A/NewYork/39/2003", "A/NewYork/4/2003", "A/NewYork/40/2003", "A/NewYork/41/2003", "A/NewYork/42/2003", "A/NewYork/43/2003", "A/NewYork/44/2003", "A/NewYork/45/2003", "A/NewYork/46/2003", "A/NewYork/47/2003", "A/NewYork/48/2003", "A/NewYork/49/2003", "A/NewYork/5/2004", "A/NewYork/50/2003", "A/NewYork/51/2003", "A/NewYork/53/2003", "A/NewYork/54/2003", "A/NewYork/55/2003", "A/NewYork/56/2003", "A/NewYork/6/2004", "A/NewYork/60A/2003", "A/NewYork/61A/2003", "A/NewYork/62A/2003", "A/NewYork/63/2003", "A/NewYork/64/2003", "A/NewYork/65/2003", "A/NewYork/67/2003", "A/NewYork/69/2004", "A/NewYork/7/2003", "A/NewYork/70/2004", "A/NewYork/8/2003"],
]

t1 = read_tree("$(dirname(pathof(TreeKnit)))/../test/NYdata/tree_ha.nwk")
t2 = read_tree("$(dirname(pathof(TreeKnit)))/../test/NYdata/tree_na.nwk")
MTK_trees = [copy(convert(Tree{TreeTools.MiscData},t1)), copy(convert(Tree{TreeTools.MiscData},t2))]
t1_original = copy(t1)
t2_original = copy(t2)

MCCs = computeMCCs(t1, t2, TreeKnit.OptArgs(rounds=1))

@testset "computeMCCs on NY data" begin
	@test MCCs[1:end-1] == MCCs_ref
end
if MCCs[1:end-1] != MCCs_ref
	@warn "Found different MCCs for the NewYork data. Could indicate a problem..."
end

"""
	function check_sort_polytomies(t1, t2, MCCs)
		
Check that leaves in the same MCC are in the same order in tree1 and tree2 after 
calling ladderize and sort_polytomies on the resolved trees. This will make sure that 
lines between nodes in an MCC do not cross when the two trees are visualized as a tanglegram.
"""
function check_sort_polytomies(t1, t2, MCCs) 
	leaf_map = map_mccs(MCCs) ##map from leaf to mcc
	pos_in_mcc_t1 = Dict()
	for leaf in POTleaves(t1)
		if haskey(pos_in_mcc_t1, leaf_map[leaf.label])
			push!(pos_in_mcc_t1[leaf_map[leaf.label]], leaf.label)
		else
			pos_in_mcc_t1[leaf_map[leaf.label]] = [leaf.label]
		end
	end

	pos_in_mcc_t2 = Dict()
	for leaf in POTleaves(t2)
		if haskey(pos_in_mcc_t2, leaf_map[leaf.label])
			push!(pos_in_mcc_t2[leaf_map[leaf.label]], leaf.label)
		else
			pos_in_mcc_t2[leaf_map[leaf.label]] = [leaf.label]
		end
	end

	sorted = true
	for mcc in 1:length(MCCs)
		if (pos_in_mcc_t1[mcc] != pos_in_mcc_t2[mcc])
			sorted = false
			break
		end
	end
	return sorted
end

rS_strict = TreeKnit.resolve!(t1, t2, MCCs; tau = 0., strict=true)
TreeTools.ladderize!(t1)
TreeKnit.sort_polytomies!(t1, t2, MCCs; strict=true)
@testset "sort_polytomies! on strict resolve! NY trees" begin
	@test check_sort_polytomies(t1, t2, MCCs)
end

MCCs_MTK = MTK.compute_mcc_pairs!(MTK_trees, TreeKnit.OptArgs(rounds=1); strict=true)
@testset "infer MCCs works the same" begin
	@test MCCs == get(MCCs_MTK, (1,2))
	@test SplitList(t1) == SplitList(MTK_trees[1])
end

@testset "compute_mcc_pairs! correctly sorts polytomies" begin
	@test check_sort_polytomies(MTK_trees[1], MTK_trees[2], get(MCCs_MTK, (1,2)))
end

MCCs_MTK = MTK.get_infered_MCC_pairs!(MTK_trees, TreeKnit.OptArgs(rounds=1); strict=true)
@testset "get_infered_MCC_pairs! correctly sorts polytomies" begin
	@test check_sort_polytomies(MTK_trees[1], MTK_trees[2], get(MCCs_MTK, (1,2)))
end


# t1 = node2tree(TreeTools.parse_newick("((A,B1),B2,C,D)"))
# t2 = node2tree(TreeTools.parse_newick("((A,B1,B2,D),C)"))
# MCCs = [["D"], ["A", "B1", "B2", "C"]]
# check_sort_polytomies(t1, t2, MCCs)
# @testset "sort_polytomies! on strict resolve! trees" begin
# 	@test check_sort_polytomies(t1, t2, MCCs)
# end
