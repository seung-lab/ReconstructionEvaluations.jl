# ReconstructionEvaluations

[![Build Status](https://travis-ci.org/seung-lab/ReconstructionEvaluations.jl.svg?branch=master)](https://travis-ci.org/seung-lab/ReconstructionEvaluations.jl)

[![Coverage Status](https://coveralls.io/repos/seung-lab/ReconstructionEvaluations.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/seung-lab/ReconstructionEvaluations.jl?branch=master)

[![codecov.io](http://codecov.io/github/seung-lab/ReconstructionEvaluations.jl/coverage.svg?branch=master)](http://codecov.io/github/seung-lab/ReconstructionEvaluations.jl?branch=master)

Package to evaluate neuronal reconstructions from electron micrographs.

Uses the NRI MATLAB method provided by the iARPA T&E team (`nri.m`).

## Install
```
Pkg.clone("https://github.com/seung-lab/ReconstructionEvaluations.git")
```


## Example
```julia
dir = joinpath(homedir(), "seungmount/Omni/TracerTasks/pinky/evaluation")
corr_fn = joinpath(dir, "corrected_cons_edges.csv")
uncorr_fn = joinpath(dir, "uncorr_cons_edges.csv")
ground_truth = load_edges(corr_fn)
reconstruction = load_edges(uncorr_fn)
count_table = build_count_table(ground_truth, reconstruction)
compute_nri(count_table)
```
