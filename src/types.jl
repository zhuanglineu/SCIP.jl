export SCIPSolver

# Common inner model

mutable struct SCIPModel
    ptr_model::Ptr{Void}
    options
    lazy_userdata
    heur_userdata

    function SCIPModel(options...)
        _arr = Array{Ptr{Void}}(1)
        # TODO: check return code (everywhere!)
        ccall((:CSIPcreateModel, libcsip), Cint, (Ptr{Ptr{Void}}, ), _arr)
        m = new(_arr[1], options)
        @assert m.ptr_model != C_NULL

        finalizer(m, freescip)
        return m
    end
end

function freescip(m::SCIPModel)
    # avoid double free
    if m.ptr_model != C_NULL
        _freeModel(m)
        m.ptr_model = C_NULL
    end
end

# Linear Quadratic Model

struct SCIPLinearQuadraticModel <: AbstractLinearQuadraticModel
    inner::SCIPModel
end

# Nonlinear Model

struct SCIPNonlinearModel <: AbstractNonlinearModel
    inner::SCIPModel
end

# Union type for common behaviour

SCIPMathProgModel = Union{SCIPLinearQuadraticModel, SCIPNonlinearModel}

# Solver

mutable struct SCIPSolver <: AbstractMathProgSolver
    options
    prefix

    function SCIPSolver(kwargs...; prefix=nothing)
        new(kwargs, prefix)
    end
end

function LinearQuadraticModel(s::SCIPSolver)
    m = SCIPLinearQuadraticModel(SCIPModel(s.options))
    setparams!(m)
    setprefix!(m, s.prefix)
    m
end

function NonlinearModel(s::SCIPSolver)
    m = SCIPNonlinearModel(SCIPModel(s.options))
    setparams!(m)
    setprefix!(m, s.prefix)
    m
end

ConicModel(s::SCIPSolver) = LPQPtoConicBridge(LinearQuadraticModel(s))
supportedcones(::SCIPSolver) = [:Free,:Zero,:NonNeg,:NonPos,:SOC]
