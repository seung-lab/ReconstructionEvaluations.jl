"""
Plot combined histogram based on group labels in last column
"""
function hist_seg_sizes(seg_list, labels=["pre", "post"])
	groups = sort(unique(seg_list[:,end]))
	@assert length(groups) <= length(labels)
	bins = logspace(0, log10(maximum(seg_list[:,2])), 50)
	for (g, l) in zip(groups, labels)
        # println((g,l))
		plt[:hist](seg_list[seg_list[:,end].==g,2], bins=bins, label=l, alpha=0.4)
	end
	ax = gca()
	legend()
	ax[:set_xscale]("log")
	title("Histogram of segment sizes");
	xlabel("Segment size (vx)")
	ylabel("Count");
end

"""
"""
function view_sparse(arr)
    # check_MATLAB()
    # put_variable(s1, :arr, arr)
    # eval_string(s1, "spy(arr)")
    plt[:spy](arr, marker=".", precision=0.1, markersize=1)
end

