# MATLAB session variable
global s1 = nothing

"""
Start MATLAB session
"""
function init_MATLAB()
    println("Starting MATLAB session...")
    global s1 = MSession()
    # cwd = joinpath(Pkg.dir("ReconstructionEvaluations"), "src")
    cwd = joinpath(pwd(), "ReconstructionEvaluations", "src")
    println("Changing MATLAB userpath to $cwd")
    eval_string(s1, "userpath('$cwd')")
end

function check_MATLAB()
    if s1 == nothing
        init_MATLAB()
    end
end