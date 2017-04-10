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
Wrapper for PyPlot's spy function

Inputs:
    arr: SparseMatrix
    precision: elements with values > precision will be plotted
    smp_i: subsample of the matrix in i
    smp_j: subsample of the matrix in j
"""
function view_sparse(arr, precision=0.1, smp_i=1, smp_j=1)
    plt[:spy](arr[1:smp_i:end,1:smp_j:end], marker=".", precision=precision, 
                                                                markersize=1)
end

"""
Remove rows and columns without a value from the adjacency matrix
"""
function crop_adj(adj)
    rdegree = sum(adj,2)[:];
    cdegree = sum(adj,1)[:];
    nzrow = rdegree .!= 0
    nzcol = cdegree .!= 0
    return adj[nzrow, nzcol]
end

"""
Sort the adjacency matrix by degree within row_label groupings

Inputs:
    adj: NxM adjacency matrix
    row_labels: Nx1 vector of row labels
    col_labels: Mx1 vector of column labels
    row_sort: sort rows by degree
    col_sort: sort columns by degree

Returns:
    sorted adjacency matrix
"""
function sort_adj(adj, row_labels, col_labels, row_sort=true, col_sort=true)
    if row_sort
        row_degree = sum(adj,2)[:]
        rdg = sortperm(row_degree, rev=true)
    else
        rdg = collect(1:size(adj,1))
    end
    if col_sort
        col_degree = sum(adj,1)[:]
        cdg = sortperm(col_degree, rev=true)
    else
        cdg = collect(1:size(adj,2))
    end
    rs = sortperm(row_labels[rdg])
    cs = sortperm(col_labels[cdg])
    return adj[rdg, cdg][rs, cs]
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
