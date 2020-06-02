module ChartmetricScraper

using HTTP,
    Dates,
    DataFrames
import JSON

export Token,
    newtoken!,
    albumrequest,
    playlistrequest,
    curatorrequest,
    Request,
    dorequest,
    parseresponse,
    offsetparser,
    getparameters,
    setparameters!

#debug exports
export buildrequest


include("helpers.jl")
include("requests.jl")
end # module
