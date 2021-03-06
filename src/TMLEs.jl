@reexport(
module TMLEs
export TMLE, tmle, iptw, gcomp

using ..LReg, ..Common

type TMLE{T<:FloatingPoint} <: AbstractScalarEstimate
    psi::T
    ic::Vector{T}
    n::Int
    estimand::String
end
TMLE(psi, ic) = TMLE(psi, ic, length(ic), "ATE")

cvec(A::Vector) = reshape(A, length(A), 1)


function tmle(logitQnA1::Vector, logitQnA0::Vector, gn1::Vector, A, Y)
    hA1 = 1.0 ./ gn1
    hA0 = -1.0 ./ (1.0 .- gn1)

    hAA = ifelse(A .==1.0, hA1, hA0)

    logitQnAA = ifelse(A .==1.0, logitQnA1, logitQnA0)

    Qnstar = lreg(cvec(hAA), Y, offset=logitQnAA)

    QnstarA1 = predict(Qnstar, cvec(hA1), offset=logitQnA1)
    QnstarA0 = predict(Qnstar, cvec(hA0), offset=logitQnA0)
    QnstarAA = ifelse(A .==1.0, QnstarA1, QnstarA0)

    psi = mean(QnstarA1) - mean(QnstarA0)
    ic = hAA .* (Y .- QnstarAA) .+ QnstarA1 .- QnstarA0 .- psi

    TMLE(psi, ic)

end

#Takes covariate matrices for Q and g, estimates Q and g with
#logistic regression, then uses those initial estimates for TMLE
function tmle(WQ::Matrix, Wg::Matrix, A::Vector, Y::Vector)

    n = length(Y)

    gn = lreg(Wg, A)
    gn1 = predict(gn, Wg)

    WQa = [WQ A]
    Qn = lreg(WQa, Y)
    WQa[:, end] = 1.0
    logitQnA1 = linpred(Qn, WQa)
    WQa[:, end] = 0.0
    logitQnA0 = linpred(Qn, WQa)


    tmle(logitQnA1, logitQnA0, gn1, A, Y)
end

tmle(W, A, Y) = tmle(W, W, A, Y)



function Base.show(io::IO, t::TMLE)
    println(io, "TMLE estimate")
    show(io, coeftable(t))
end

#     se = sqrt(var(t.ic) / length(t.ic))
#     ul = t.psi .+ [-1.96, 1.96] * se
#     Base.println(io, "psi: ", t.psi)
#     Base.println(io, "se: ", se)
#     Base.println(io, "ci: (", ul[1], ", ", ul[2], ")")
# end

function gcomp(W, A, Y)
    n = length(Y)

    Qn = lreg([W A], Y)
    QnA1 = predict(Qn, [W ones(n)])
    QnA0 = predict(Qn, [W zeros(n)])

    mean(QnA1) - mean(QnA0)

end

function iptw(W, A, Y)
    gn = lreg(W, A)
    gn1 = predict(gn, W)

    mean(((A ./ gn1) - ((1.0 .- A)./ (1.0 .- gn1))) .* Y)
end



end)
