# Locally Linear Embedding (LLE)
# ------------------------
# Nonlinear dimensionality reduction by locally linear embedding,
# Roweis, S. & Saul, L., Science 290:2323 (2000)

#### LLE type
immutable LLE <: SpectralResult
    k::Int
    λ::Vector{Float64}
    proj::Projection

    LLE(k::Int, λ::Vector{Float64}, proj::Projection) = new(k, λ, proj)
end

## properties
indim(M::LLE) = size(M.proj, 1)
outdim(M::LLE) = size(M.proj, 2)
projection(M::LLE) = M.proj

eigvals(M::LLE) = M.λ
nneighbors(M::LLE) = M.k

## show & dump
function show(io::IO, M::LLE)
    print(io, "LLE(indim = $(indim(M)), outdim = $(outdim(M)), nneighbors = $(nneighbors(M)))")
end

function dump(io::IO, M::LLE)
    show(io, M)
    println(io, "eigenvalues: ")
    Base.showarray(io, M.λ', header=false, repr=false)
    println(io)
    println(io, "projection:")
    Base.showarray(io, M.proj, header=false, repr=false)
end

## interface functions
function fit(::Type{LLE}, X::DenseMatrix{Float64}; d::Int=2, k::Int=12)
    n = size(X, 2)

    # Construct NN graph
    D, E = find_nn(X, k)

    # Select largest connected component
    cc = components(E)
    c = cc[indmax(map(size, cc))]
    if length(cc) == 1
        c = cc[1]
    else
        c = cc[indmax(map(size, cc))]
        # renumber edges
        R = Dict(c, 1:length(c))
        Ec = zeros(Int,k,length(c))
        for i = 1 : length(c)
            Ec[:,i] = map(i->get(R,i,0), E[:,c[i]])
        end
        E = Ec
        X = X[:,c]
    end

    if k > d
        warn("K>D: regularization will be used")
        tol = 1e-5
    else
        tol = 0
    end

    # Reconstruct weights
    W = zeros(k, n)
    for i = 1 : n
        Z = X[:, E[:,i]] .- X[:,i]
        C = Z'*Z
        C = C + eye(k, k) * tol * trace(C)
        wi = vec(C\ones(k, 1))
        W[:, i] = wi./sum(wi)
    end

    # Compute embedding
    M = eye(n,n) # speye(n,n)
    for i = 1 : n
        w = W[:, i]
        jj = E[:, i]
        M[i,jj] = M[i,jj] - w'
        M[jj,i] = M[jj,i] - w
        M[jj,jj] = M[jj,jj] + w*w'
    end

    λ, V = decompose(M, d)
    return LLE(k, λ, V' .* sqrt(n))
end