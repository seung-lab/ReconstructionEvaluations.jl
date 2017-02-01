function test_overlap()
    gt = [1 2;
          1 3]
    o =  [1 2;
          4 2]
    gt_to_o = create_segID_map(gt, o)
    o_to_gt = create_segID_map(o, gt)
    @test gt_to_o == Dict(1 => [UInt32(1), UInt32(4)],
                          2 => [UInt32(2)],
                          3 => [UInt32(2)])
    @test o_to_gt == Dict(1 => [UInt32(1)],
                          2 => [UInt32(2), UInt32(3)],
                          4 => [UInt32(1)])
    gt_splits = count_splits(gt_to_o)
    o_splits = count_splits(o_to_gt)
    @test gt_to_o == Dict(1 => 2,
                          2 => 1,
                          3 => 1)
    @test o_to_gt == Dict(1 => 1,
                          2 => 2,
                          4 => 1)
end