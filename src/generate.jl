module generate

using HDF5
using LinearAlgebra
using ArbNumerics, Tullio, LoopVectorization, Nemo
using GenericLinearAlgebra
using Distributions

#################
### Constant ####
#################

function constants()
    mplanck_r::ArbFloat = ArbFloat(2.435e18)
    hubble::ArbFloat = ArbFloat(2.13*0.7*1e-33)
    log2pi::ArbFloat = ArbFloat(log10(2*pi))
    return mplanck_r,hubble,log2pi
end


###############################
##### Pseudo-Geometric data ###
###############################


function pseudo_Q(h11::Int,tri::Int,cy::Int=1)
    Q = vcat(Matrix{Float64}(I(h11)),rand(-5.:5.,4,h11))
    return vcat(Q,hcat([Q[i,:]-Q[j,:] for i=1:size(Q,1)-1 for j=i+1:size(Q,1)]...)')
end

function pseudo_K(h11::Int,tri::Int,cy::Int=1)
    K::Matrix{Float64} = rand(h11,h11)
    K = 4* 0.5 * (K+transpose(K)) + 2 .* I(h11)
    return Hermitian(K)
end

function pseudo_L(h11::Int,tri::Int,cy::Int=1)
    Llogprime::Vector{Float64} = sort(vcat([0,[-(4*(j-1)) for j=2:h11+4]...]),rev=true)
    Lsignh11::Vector{Float64} = rand(Uniform(0,100),h11-1)
    Lsign4::Vector{Float64} = rand(Uniform(-100,100),4)
    Lsignprime::Vector{Float64} = vcat(1.,Lsignh11..., Lsign4...)
    Llogcross::Vector{Float64} = [Llogprime[i] + Llogprime[j] for i=1:size(Llogprime,1)-1 for j=i+1:size(Llogprime,1)]
    Lsigncross::Vector{Float64} = [Lsignprime[i] * Lsignprime[j] for i=1:size(Lsignprime,1)-1 for j=i+1:size(Lsignprime,1)]
    Llogtemp::Vector{Float64} = vcat(Llogprime...,Llogcross...)
    Lsigntemp::Vector{Float64} = vcat(Lsignprime...,Lsigncross...)
    Ltemp::Vector{ArbFloat} = ArbFloat.(Lsigntemp) .* ArbFloat(10.) .^ ArbFloat.(Llogtemp)
    return Ltemp
end

function pseudo_Llog(h11::Int,tri::Int,cy::Int=1)
    L1 = [1 1]
    L2 = vcat([[1 -(4*(j-1))] for j=2:h11+4]...)
    L3 = vcat([[sign(rand(Uniform(-100. *h11,100. *h11))) -(4*(j-1))+log10(abs(rand(Uniform(-100. *h11,100. *h11))))]
     for j=h11+5:h11+4+binomial(h11+4,2)]...)
    L4 = @.(log10(abs(L3)))
    return vcat(L1,L2,L3)
end

##############################
#### Computing Spectra #######
##############################

function hp_spectrum(h11::Int,K::Hermitian{Float64, Matrix{Float64}}, L::Matrix{Float64}, Q::Matrix{Int}; prec=5_000)
    setprecision(ArbFloat,digits=prec)
    Lh::Vector{ArbFloat}, Qtest::Matrix{ArbFloat} = L[:,1] .* ArbFloat(10.) .^L[:,2], ArbFloat.(Q)
    #Compute Hessian (in lattice basis)
    grad2::Matrix{ArbFloat} = zeros(ArbFloat,(h11,h11))
    hind1::Vector{Vector{Int64}} = [[x,y]::Vector{Int64} for x=1:h11,y=1:h11 if x>=y]
    grad2_temp::Vector{ArbFloat} = zeros(ArbFloat,size(hind1,1))
#     Lh::Vector{ArbFloat} = zeros(ArbFloat,size(Ltemp,1))
#     @inbounds for i=1:size(Lh,1)
#         Lh[i] = Ltemp[i,1] .* Ltemp[i,2] .* 10. .^ Ltemp[i,3]
#     end
    
    grad2_temp1::Matrix{ArbFloat} = zeros(ArbFloat,size(Lh,1),size(hind1,1))
#     xh::Vector{ArbFloat} = x(h11,tri,cy)
    @tullio grad2_temp1[c,k] = @inbounds(begin
    i,j = hind1[k]
            Qtest[c,i] * Qtest[c,j] end) grad=false fastmath=false
    @tullio grad2_temp[k] = grad2_temp1[c,k] * Lh[c]
    @inbounds for i=1:size(hind1,1)
        j,k = hind1[i]
        grad2[j,k] = grad2_temp[i]
    end
    hessfull = Hermitian(grad2 + transpose(grad2) - Diagonal(grad2))
    Lh = zeros(3)
    #Compute QM using generalised eigendecomposition (but keep fK)
    Ktest = Hermitian(ArbFloat.(K))
    fK::Vector{Float64} = Float64.(log10.(sqrt.(eigen(Ktest).values)))
    Vls::Vector{ArbFloat},Tls::Matrix{ArbFloat} = eigen(hessfull, Ktest)
    Hsign::Vector{Int64} = @.(sign(Vls))
    Hvals::Vector{Float64} = @.(log10(sqrt(abs(Vls))))
    QMs::Matrix{ArbFloat} = similar(Qtest)
    multH(M,N) = @tullio fastmath=false grad=false R[c,i] := M[c,j] * N[j,i]
    QMs = multH(Qtest,Tls)
    signQMs::Matrix{Int64} = @.(Int(sign(QMs)))
    logQMs::Matrix{Float64} = @.(Float64(log(abs(QMs))))
    
    #Clear memory
    Vls = zeros(ArbFloat,1)
    Tls = zeros(ArbFloat,1,1)
    QMs = zeros(ArbFloat,1,1)
    Qtest = zeros(ArbFloat,1,1)
    hessfull = zeros(ArbFloat,1,1)
    grad2_temp1 = zeros(ArbFloat,1,1)
    grad2_temp = zeros(ArbFloat,1)
    grad2 = zeros(ArbFloat,1,1)
    Ktest = zeros(ArbFloat,1,1)
#     GC.gc()
    
    #Generate quartics in logspace
    signL::Vector{Int},L1::Vector{Float64}, logL2::Vector{Float64} = sign.(L[:,1]), L[:,1], L[:,2]
    logL::Vector{Float64} = log.(abs.(L1)) .+ (logL2 .* log(10.))
    #Compute quartics
    qindq31::Vector{Vector{Int64}} = [[x,x,x,y]::Vector{Int64} for x=1:h11,y=1:h11 if x!=y]
    qindq22::Vector{Vector{Int64}} = [[x,x,y,y]::Vector{Int64} for x=1:h11,y=1:h11 if x>y]
    quart31log1::Matrix{Float64} = zeros(Float64,size(logL,1),size(qindq31,1))
    quart22log1::Matrix{Float64} = zeros(Float64,size(logL,1),size(qindq22,1))
    quartiilog1::Matrix{Float64} = zeros(Float64,size(logL,1),h11)
    quart31sign1::Matrix{Float64} = zeros(Int64,size(logL,1),size(qindq31,1))
    quart22sign1::Matrix{Float64} = zeros(Int64,size(logL,1),size(qindq22,1))
    quartiisign1::Matrix{Float64} = zeros(Int64,size(logL,1),h11)
    quart31log::Vector{Float64} = zeros(Float64,size(qindq31,1))
    quart22log::Vector{Float64} = zeros(Float64,size(qindq22,1))
    quartdiaglog::Vector{Float64} = zeros(Float64,h11)
    quart31sign::Vector{Int} = zeros(Int,size(qindq31,1))
    quart22sign::Vector{Int} = zeros(Int,size(qindq22,1))
    quartdiagsign::Vector{Int} = zeros(Int,h11)
    @inbounds for k=1:size(qindq31,1)
        i,_,_,j = qindq31[k]
        quart31sign1[:,k] = signL .* signQMs[:,i] .* signQMs[:,i] .* signQMs[:,i] .* signQMs[:,j]
        quart31log1[:,k] = logL .+ (logQMs[:,i] + logQMs[:,i] .+ logQMs[:,i] + logQMs[:,j])
        quart31sign[k],quart31log[k] = gauss_log(quart31sign1[:,k],quart31log1[:,k])
    end
    @inbounds for k=1:size(qindq22,1)
        i,_,_,j = qindq22[k]
        quart22sign1[:,k] = signL .* signQMs[:,i] .* signQMs[:,i] .* signQMs[:,j] .* signQMs[:,j]
        quart22log1[:,k] = logL .+ (logQMs[:,i] + logQMs[:,i] .+ logQMs[:,j] + logQMs[:,j])
        quart22sign[k],quart22log[k] = gauss_log(quart22sign1[:,k],quart22log1[:,k])
    end
    @inbounds for k=1:h11
        quartiisign1[:,k] = signL .* signQMs[:,k] .* signQMs[:,k] .* signQMs[:,k] .* signQMs[:,k]
        quartiilog1[:,k] = logL .+ (logQMs[:,k] + logQMs[:,k] .+ logQMs[:,k] + logQMs[:,k])
        quartdiagsign[k],quartdiaglog[k] = gauss_log(quartiisign1[:,k],quartiilog1[:,k])
    end
    qindqdiag::Vector{Vector{Int64}} = [[x,x,x,x]::Vector{Int64} for x=1:h11]
    
    fpert::Vector{Float64} = @.(Hvals+log10(constants()[1])- (0.5*quartdiaglog*log10(exp(1))))
#     return Hvals .+ Float64(log10(constants()[1])) .+ Float64(constants()[end]) .+9,
#     fpert .- Float64(constants()[end]),quartdiagsign,quartdiaglog .* log10(exp(1)) .+ 4*Float64(constants()[end])
    return quartdiaglog .*log10(exp(1)) .+ 4*Float64(constants()[end]), quartdiagsign, 
    fK .+ Float64(log10(constants()[1])) .- Float64(constants()[end]), fpert .- Float64(constants()[end]), 
    quart31log .*log10(exp(1)) .+ 4*Float64(constants()[end]), quart31sign, Array(hcat(qindq31...) .-1), 
    quart22log .*log10(exp(1)) .+ 4*Float64(constants()[end]), quart22sign, Array(hcat(qindq22...) .-1), 
    Hvals .+ Float64(log10(constants()[1])) .+9 .+ Float64(constants()[end]), Hsign
#     GC.gc()
end


function hp_spectrum_save(h11::Int,tri::Int,cy::Int=1)
    if h11!=0
        test_data = cyax_potential_read(h11,tri,cy);
        L::Matrix{Float64}, Q::Matrix{Int}, K = test_data["L"],test_data["Q"],test_data["K"]
        quartdiaglog::Vector{Float64}, quartdiagsign::Vector{Int}, fK::Vector{Float64}, fpert::Vector{Float64}, 
        quart31log::Vector{Float64}, quart31sign::Vector{Int}, 
        qindq31::Array{Int}, quart22log::Vector{Float64}, quart22sign::Vector{Int}, 
        qindq22::Array{Int}, Hvals::Vector{Float64}, Hsign::Vector{Int} = quart_large_out(h11,K,L[1:h11+4,:],Q[1:h11+4,:])
        Lfull::Vector{ArbFloat} = ArbFloat.(L[:,1]) .* ArbFloat(10.) .^ ArbFloat.(L[:,2])
        vacua::Int, θparallel::Matrix{Rational}, Qtilde::Matrix{Int} = vacua_out(h11,Q,Lfull)
        h5open(cyax_file(h11,tri,1), "r+") do file
            f3 = create_group(file, "vacua")
            f3["vacua",deflate=9] = vacua
            f3["Qtilde",deflate=9] = Qtilde
            f3a = create_group(f3, "thparallel")
            f3a["numerator",deflate=9] = numerator.(θparallel)
            f3a["denominator",deflate=9] = denominator.(θparallel)


            f2 = create_group(file, "spectrum")
            f2a = create_group(f2, "quartdiag")
            f2a["log10",deflate=9] = quartdiaglog
            f2a["sign",deflate=9] = quartdiagsign
            f2e = create_group(f2, "decay")
            f2e["fpert",deflate=9] = fpert
            f2e["fK",deflate=9] = fK

            f2b = create_group(f2, "quart31")
            f2b["log10",deflate=9] = quart31log
            f2b["sign",deflate=9] = quart31sign
            f2b["index",deflate=9] = qindq31

            f2c = create_group(f2, "quart22")
            f2c["log10",deflate=9] = quart22log
            f2c["sign",deflate=9] = quart22sign
            f2c["index",deflate=9] = qindq22

            f2d = create_group(f2, "Heigvals")
            f2d["log10",deflate=9] = Hvals
            f2d["sign",deflate=9] = Hsign
        end
    end
    GC.gc()
end

function project_out(v::Vector{Float64})
    idd = Matrix{Float64}(I(size(v,1)))
    norm2 = dot(v,v)
    proj = 1. /norm2 * (v * v')
    return idd-proj
end

function pq_spectrum(K::Hermitian{Float64, Matrix{Float64}}, L::Matrix{Float64}, Q::Matrix{Int})
    h11 = size(K,1)
    fK = log10.(sqrt.(eigen(K).values))
    Kls = cholesky(K).L
#     multH(M,N) = @tullio fastmath=false grad=false R[c,i] := M[c,j] * N[j,i]
    LQtest = hcat(L,Q);
    Lfull::Vector{Float64} = log10.(abs.(LQtest[:,1])) .+  LQtest[:,2]
    LQsorted = LQtest[sortperm(Lfull, rev=true), :]
    Lsorted_test,Qsorted_test = LQsorted[:,1:2], Int.(LQsorted[:,3:end])
    Qtilde = Qsorted_test[1,:]
    Qdtilde = zeros(size(Qsorted_test[1,:],1))
    Ltilde = Lsorted_test[1,:]
    Ldtilde = zeros(size(Lsorted_test[1,:],1))
    for i=2:size(Qsorted_test,1)
        S = MatrixSpace(Nemo.ZZ, size(Qtilde,1), (size(Qtilde,2)+1))
        m = S(hcat(Qtilde,Qsorted_test[i,:]))
        (d,bmat) = Nemo.nullspace(m)
        if d == 0
            Qtilde = hcat(Qtilde,Qsorted_test[i,:])
            Ltilde = hcat(Ltilde,Lsorted_test[i,:])
        else
            Qdtilde = hcat(Qdtilde,Qsorted_test[i,:])
            Ldtilde = hcat(Ldtilde,Lsorted_test[i,:])
        end
    end
    QKs = zeros(h11,h11)
    fapprox = zeros(h11)
    mapprox = zeros(h11)
    LinearAlgebra.mul!(QKs, inv(Kls'), Qtilde')
    QKs = QKs'
    for i=1:h11
#         println(size(QKs))
        fapprox[i] = log10(1/(2π*dot(QKs[i,:],QKs[i,:])))
        mapprox[i] = 0.5*(log10(abs(Ltilde[1,i]))+Ltilde[2,i]-fapprox[i])
        proj = project_out(QKs[i,:])
        #this is the scipy.linalg.orth function written out
        u, s, vh = svd(proj,full=true)
        M, N = size(u,1), size(vh,2)
        rcond = eps() * max(M, N)
        tol = maximum(s) * rcond
        num = Int.(round(sum(s[s .> tol])))
        T = u[:, 1:num]
        QKs1 = zeros(size(QKs,1), size(T,2))
        LinearAlgebra.mul!(QKs1,QKs, T)
        QKs = copy(QKs1)
    end
    return hcat(fK .+ Float64(log10(constants()[1])) .- Float64(constants()[end]),
        0.5 .* fapprox[sortperm(mapprox)] .+ Float64(log10(constants()[1])), 
        mapprox[sortperm(mapprox)] .+ 9. .+ Float64(log10(constants()[1])))
end

end