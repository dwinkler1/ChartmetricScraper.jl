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
    getparameters,
    setparameters!,
    writestate

#debug exports
export buildrequesturl

include("token.jl")
include("request.jl")
include("helpers.jl")
include("requests_helpers.jl")
end # module
