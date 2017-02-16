edges = [[2000, [35, 40], [355,500,600], 1000],
        [2001, [35, 50], [100,500,600], 2000],
        [2002, [37, 40], [100,400,600], 3000]];
edges = hcat(edges...)';

create_graph_dicts(edges)

# pre_to_post, post_to_pre = create_post_pre_dicts(segs)
@test length(pre_to_post[35]) == 2
@test pre_to_post[35][1] == 40
@test pre_to_post[35][2] == 50
@test pre_to_post[37][1] == 40
@test post_to_pre[40][1] == 35
@test post_to_pre[40][2] == 37
@test post_to_pre[50][1] == 35