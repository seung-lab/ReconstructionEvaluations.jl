

@testset "nri" begin

  #example om from NRI paper
  om1 = [0 0 0 0 0; 0 2 0 0 1;
         0 0 0 1 0; 0 0 3 0 0;
         0 1 0 0 0];

  fullTPs, segTPs = compute_TPs(om1)

  @test segTPs[1] == 0
  @test segTPs[2] == 1
  @test segTPs[3] == 0
  @test segTPs[4] == 3
  @test segTPs[5] == 0

  fullFPs, segFPs = compute_FPs(om1)

  @test segFPs[1] == 0
  @test segFPs[2] == 1
  @test segFPs[3] == 0
  @test segFPs[4] == 0
  @test segFPs[5] == 1

  fullFNs, segFNs = compute_FNs(om1)

  @test segFNs[1] == 0
  @test segFNs[2] == 2
  @test segFNs[3] == 0
  @test segFNs[4] == 0
  @test segFNs[5] == 0

  fullNRI, segNRI = nri(om1)

  @test segNRI[2] == 0.4
  @test segNRI[4] == 1
  @test segNRI[5] == 0

end
