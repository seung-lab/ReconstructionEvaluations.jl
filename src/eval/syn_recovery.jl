#!/usr/bin/env julia

#A few utilities to estimate the percentage of detached
# dendritic spines

"""

    find_trunk_mapping( om, trunk_list )

Given an overlap matrix and list of segment ids, find the segments
which overlap the most in the compared segmentation. If the segment
arguments are trunks, the results are likely to correspond to the
same trunks in the comparison segmentation.
"""
function find_trunk_mapping( om, trunk_list )

    trunk_om = om[trunk_list,:];

    maxs, inds = findmax(trunk_om,2)
    matches = ind2sub( size(trunk_om), inds[:] )[2]

    Dict( trunk_list[i] => matches[i] for i in eachindex(matches) )
end


"""

    synapse_recovery( uncorr_es, corr_es, trunk_mapping )

Given synapse tables (as read by load_edges) and a trunk mapping,
determine the ratio between the number of synapses innervating the
mapped segments in each segmentation.
"""
function synapse_recovery( uncorr_es, corr_es, trunk_mapping )

    corr_segs = corr_es[:,2]; uncorr_segs = uncorr_es[:,2];

    corr_trunks = Set(keys(trunk_mapping))
    uncorr_trunks = Set(values(trunk_mapping))

    num_corr_trunk_syns = count( x -> x[2] in corr_trunks, corr_segs )
    num_uncorr_trunk_syns = count( x -> x[2] in uncorr_trunks, uncorr_segs )

    num_uncorr_trunk_syns / num_corr_trunk_syns
end

