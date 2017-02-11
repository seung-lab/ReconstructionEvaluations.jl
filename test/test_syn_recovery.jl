#!/usr/bin/env julia

@testset "synapse recovery" begin

    om = sparse([0 3; 3 0]);

    tm = find_trunk_mapping(om, [1,2])
    @test tm[2] == 1
    @test tm[1] == 2


    om = sparse([3 0; 0 3]);

    tm = find_trunk_mapping(om, [1,2])
    @test tm[1] == 1
    @test tm[2] == 2


    uncorr_es = Array{Any}(2,4); corr_es = Array{Any}(2,4);

    uncorr_es[1,:] = [1, [1,2], [1,1,1], 1];
    uncorr_es[2,:] = [2, [3,4], [2,2,2], 1];

    corr_es[1,:] = [1, [1,2], [1,1,1], 1];
    corr_es[2,:] = [2, [5,6], [3,3,3], 1];

    tm1 = Dict( 2 => 2, 6 => 4 )
    tm2 = Dict( 2 => 2, 6 => 6 )
    @test synapse_recovery(uncorr_es, corr_es, tm1) == 1
    @test synapse_recovery(uncorr_es, corr_es, tm2) == (1/2)
end
