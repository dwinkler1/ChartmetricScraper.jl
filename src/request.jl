
"""
    Request(token::Token, url::String[, maxtries::Int, sleeptime::Number, state::Dict])
    Request(refreshtoken::String, url::String[, maxtries::Int, sleeptime::Number])

Creates a `Request` to be used with `dorequest(...)`

# Arguments:
- `token` : the request `Token`
- `url` : Chartmetric URL to be requested
- [`maxtries`] : maximum number of tries to get the request (default = `token.maxtries`)
- [`sleeptime`] : Time to wait after server error in seconds (default = 600)
- [`state`] : Metadata for a request. Allows multiple requests of the same variable with different offset.
- `refreshtoken` : Chartmetric refreshtoken associated with your account
"""
mutable struct Request
    token::Token
    url::String
    maxtries::Int
    sleeptime::Number
    state::Dict
    function Request(token::Token, url, maxtries = nothing, sleeptime::Number = 600; state = Dict())
        tokenprotector!(token)
        @assert sleeptime >= 0 "sleeptime cannot be negative"
        maxtries === nothing && (maxtries = token.maxtries)
        @assert maxtries > 0 "maxtries must be positive"

        return new(token, url, maxtries, sleeptime, state)
    end # fun
end # struct

Request(refreshtoken::String, url, maxtries = nothing, sleeptime = 600; state = Dict()) = Request(Token(refreshtoken), url, maxtries, sleeptime, state = state)

# Exported


"""
    dorequest(request::Request)

Run the request using a `Request` object

# Arguments:
- `request` : the `Request` object
"""

function dorequest(request::Request)
    tokenprotector!(request.token)
    token = request.token
    url = request.url
    maxtries = request.maxtries
    header = ["Authorization" => string("Bearer ", token.token)]
    req = :(HTTP.request("GET",
                $url, $header, status_exception = false))
    resp = eval(req)
    code = requestprotector(resp, token)
    if code ∉ 200:399
        for i ∈ 1:(maxtries-1)
            resp = eval(req)
            code = requestprotector(resp, token)
            code ∈ 200:399 && break
            if i == (maxtries-1)
                @warn "Error getting request"
                println(resp)
            end # if
        end # for
    end # if
    return resp
end # fun

function getparameters(request::Request)
    url = request.url
    !occursin(r"\?", url) && return String[]
    paramstring = match(r"(?<=\?).*", url)
    params = split(paramstring.match, '&')
    return params
end

function setparameters!(request::Request, parameters::Array{String,1}; add::Bool = false)
    parameters = parameters[length.(parameters) .> 0]
    url_old = request.url
    add && append!(parameters, getparameters(request))

    parameters = replace.(parameters, r"\s+" => "")
    paramstring = join(parameters, '&')
    hasparam = length(paramstring)>0
    if occursin(r"\?", url_old)
        url_base = match(r".*(?=\?)", url_old).match
        url_new = hasparam ? url_base * '?' * paramstring : url_base
    else
        url_new = hasparam ? url_old * '?' * paramstring : url_old
    end
    request.url = url_new
    return request
end

function writestate(request::Request, file)
    open(file, "w+") do io
        JSON.print(io, request.state)
    end
    return file
end

function readstate!(request::Request, file)
    out = Dict()
    open(file) do io
        for l in eachline(io)
            merge!(out, JSON.parse(l))
        end
    end
    request.state = out
    return request
end
