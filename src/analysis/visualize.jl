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

"""
Place indices of points on 3d plots

Inputs:
    ax: PyPlot axis (e.g. ax = gca())
    points: Nx2/3 array of points
"""
function label3d(ax, points)
    for i in 1:size(cluster_centroid,1)
        ax[:text](cluster_centroid[i,:]...,"$i")
    end
end    

"""
Plot sphere in PyPlot with center, ctr, and radius, r

Inputs:
    ctr: 3-element array
    r: real no radius
    n: resolution of the sphere
    alpha: opacity of the sphere
"""
function plot_sphere(ctr, r, n=10, alpha=0.02)
    u = linspace(0, 2*pi, n)
    v = linspace(0, pi, n)
    x = r*cos(u)*sin(v)' + ctr[1]
    y = r*sin(u)*sin(v)' + ctr[2]
    z = r*ones(size(u,1))*cos(v)' + ctr[3]
    plot_surface(x,y,z, alpha=alpha, shade=true, linewidth=0)
end;

"""
Visualize NRI breakdowns per segment for TP, FP, FN
"""
function plot_NRI(nN, roc)
    function hist_nan(a)
        b = a[a .> 0]
        plt[:hist](b, bins=20);
        ax = gca()
        ax[:set_yscale]("log")
    end
    
    fig = figure()
    subplot(221)
    hist_nan(nN)
    title("per seg NRI")
    subplot(222)
    hist_nan(roc["TP"])
    title("per seg TP")
    subplot(223)
    hist_nan(roc["FP"])
    title("per seg FP")
    subplot(224)
    hist_nan(roc["FN"])
    title("per seg FN")
end