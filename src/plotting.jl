module plotting
##############################
#### Plotting functions ######
##############################

using ..filestructure: plots_dir, count_geometries, paths_cy
using ..generate: jlm_vacua_db
using CairoMakie, ColorSchemes


"""
    vacua_db_jlm(n)

TBW
"""
function vacua_db_jlm(vac_data::NamedTuple)
    f = Figure()
    kwargs = (; xticklabelfont = "STIX", yticklabelfont = "STIX", xminorticksvisible = true, xminorgridvisible = true, yminorticksvisible = true, yminorgridvisible = true)
    ax1 = Axis(f[2, 1]; xticks = [4, 50, 100, 200, 300, 400, 491], xminorticks = IntervalsBetween(5), yscale = Makie.pseudolog10, kwargs...)
    ax2 = Axis(f[2, 2]; xticks = [4, 50, 100, 200, 300, 400, 491], xminorticks = IntervalsBetween(5), yscale = Makie.pseudolog10, yticks = [1, 10, 50, 100, 500, 1000, 2000], kwargs...)
    ax3 = Axis(f[1, 1:3]; xticks = [4, 50, 100, 200, 300, 400, 491], yscale = Makie.pseudolog10, kwargs...)
    square_vac = hcat([vcat(item[1], item[4]) for item in vac_data.square]...)
    n_dim_vac = hcat([vcat(item[1], item[4], item[end]) for item in vac_data.n_dim]...)
    n_dim_vac = n_dim_vac[:, sortperm(n_dim_vac[end, :])]
    one_dim_vac = hcat([vcat(item[1], item[4]) for item in vac_data.one_dim]...)
    sc_square = scatter!(ax3, square_vac[1, square_vac[2, :] .!= 0], square_vac[2, square_vac[2, :] .!= 0], marker = :circle, color = :green, markersize = 10, label = "0 extra rows")
    sc_onedim = scatter!(ax1, one_dim_vac[1, one_dim_vac[2, :] .!= 0], one_dim_vac[2, one_dim_vac[2, :] .!= 0], color = :cyan, marker = :utriangle, markersize = 10, label = "1 extra row")
    sc_ndim = scatter!(ax2, n_dim_vac[1, n_dim_vac[2, :] .!= 0], n_dim_vac[2, n_dim_vac[2, :] .!= 0], color = n_dim_vac[3, n_dim_vac[2, :] .!= 0], colormap = :thermal, marker = :rect, markersize = 10, label = L"$N$ extra rows")
    axislegend(ax3, [sc_square, sc_onedim, sc_ndim], [L"$0$", L"$1$", L"$N$"], "Number of Extra Rows", orientation = :horizontal, titlefont = "STIX Bold")
    Colorbar(f[2,3], limits = (minimum(n_dim_vac[3, n_dim_vac[2, :] .!= 0]), maximum(n_dim_vac[3, n_dim_vac[2, :] .!= 0])), colormap = :thermal, label = L"$N$", ticklabelfont = "STIX")
    Label(f[1:end, 0], L"$N_\mathrm{vacua}$", rotation = π/2)
    Label(f[end+1, 1:end], L"$h^{1,1}$")
    save(joinpath(plots_dir(), "N_vac_KS.pdf"), f, pt_per_unit = 1)
end

function vacua_db_jlm(n=size(paths_cy()[2], 2))
    vac_data = jlm_vacua_db(n)
    vac_square = hcat([vcat(item[1:4]...) for item in vac_data.square]...)
	vac_1D = hcat([vcat(item[1:4]...) for item in vac_data.one_dim]...)
	vac_ND = hcat([vcat(item[1:4]..., item[end]...) for item in vac_data.n_dim]...)
	all_vacua = hcat(vac_square, vac_1D, vac_ND[1:4, :])
    println(size(all_vacua))
    vacua_db_jlm(vac_data)
end


function total_geometries(n=nothing)
    total_geoms = count_geometries(n)
    fig_h11size = Figure()
	CairoMakie.barplot(fig_h11size[1,1], hcat(total_geoms...)[1,:], hcat(total_geoms...)[2,:])
    save(joinpath(plots_dir(), "total_geometries.pdf"), fig_h11size, pt_per_unit = 1)
end

"""
    vacua_db_jlm_box(square::Matrix, one_dim::Matrix, n_dim::Matrix)

TBW
"""
function vacua_db_jlm_box(square::Matrix, one_dim::Matrix, n_dim::Matrix)
	vacua_full = sortslices(hcat(square, one_dim, n_dim[1:4, :]), dims = 2, by=x->x[2])
    size_inches = (36, 48)
	size_pt = 72 .* size_inches
    colors = resample_cmap(:twilight, size(collect(Set(vacua_full[1,:])), 1))
    f = Figure(resolution = size_pt, fontsize=48)
    kwargs = (; xticklabelfont = "STIX", yticklabelfont = "STIX", ylabel =L"$h^{1,1}$", xlabel =  L"$\mathcal{N}_{\!\!\mathrm{vac}}$", xminorticksvisible = true, xminorgridvisible = true, yminorticksvisible = true, yminorgridvisible = true, xlabelsize = 60, ylabelsize = 60, yminorticks = IntervalsBetween(5), palette = (; patchcolor = colors))
    ax1 = Axis(f[1, 1]; xticks = [4, 50, 100, 200, 300, 400, 491], kwargs...)
    for item in sort(collect(Set(vacua_full[1, :])))
        CairoMakie.boxplot!(ax1, vacua_full[1, vacua_full[1, :] .== item], vacua_full[end, vacua_full[1, :] .== item], orientation = :horizontal, marker = :xcross, markersize = 10, whiskerwidth = 0.75, width = 0.9)
    end
    save(joinpath(plots_dir(), "N_vac_KS_box.pdf"), f, pt_per_unit = 1)
end

function vacua_db_jlm_box(vacua_db::NamedTuple)
    square = hcat(vacua_db.square...)
	one_dim = hcat([item[1:4] for item in vacua_db.one_dim]...)
	n_dim = hcat([[item[1:4]...,item[end]] for item in vacua_db.n_dim if item[4] != 0]...)
	vacua_db_jlm_box(square, one_dim, n_dim)
end




end