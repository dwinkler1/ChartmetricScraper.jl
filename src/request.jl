
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
    function Request(token::Token, url; maxtries = nothing, sleeptime::Number = 600, state = Dict())
        tokenprotector!(token)
        @assert sleeptime >= 0 "sleeptime cannot be negative"
        maxtries === nothing && (maxtries = token.maxtries)
        @assert maxtries > 0 "maxtries must be positive"

        return new(token, url, maxtries, sleeptime, state)
    end # fun
end # struct

Request(refreshtoken::String, url; maxtries = nothing, sleeptime = 600, state = Dict()) = Request(Token(refreshtoken), url, maxtries = maxtries, sleeptime = sleeptime, state = state)

# Exported


"""
    dorequest(request::Request)

Run the request using a `Request` object

# Arguments:
- `request` : the `Request` object
- `skip404 = true` : If `true` 404 errors will not be retried
- `verbose = false` : If `true` all unusual events (e.g. rate limit is hit) will print a message
"""
function dorequest(request::Request; skip404 = true, verbose = false)
    tokenprotector!(request.token)
    token = request.token
    url = request.url
    maxtries = request.maxtries
    header = ["Authorization" => string("Bearer ", token.token)]
    req = :(HTTP.request("GET",
                $url, $header, status_exception = false))
    resp = eval(req)
    code = requestprotector(resp, request, verbose = verbose)
    if code ∉ 200:399
        for i ∈ 1:(maxtries-1)
            if skip404 && code == 404
                @warn "404 error getting request"
                println(request.url)
                break
            end
            resp = eval(req)
            code = requestprotector(resp, request, verbose = verbose)
            code ∈ 200:399 && break
            if i == (maxtries-1)
                @warn "Error getting request"
                #println(resp)
            end # if
        end # for
    end # if
    return resp
end # fun

"""
    getparsed(tkn, path, parameters = nothing; kwargs...)

Do a full request and return a Dict of the response. Keyword arguments are passed to [Request](@ref) and are `maxtries` and `sleeptime`.

# Arguments:
- `token`: the request `Token`
- `path`: Chartmetric API path
- `parameters=nothing`: Chartmetric parameters of the form ["limit=100", "since=2020-01-01"] 
- `skip404 = true` : If `true` 404 errors will not be retried
- `verbose = false` : If `true` all unusual events (e.g. rate limit is hit) will print a message
"""
function getparsed(token, path, parameters = nothing, skip404 = true, verbose = false; maxtries = 5, sleeptime = 2)
    url = buildrequesturl(path)
    req = Request(token, url; maxtries = maxtries, sleeptime = sleeptime)
    if !isnothing(parameters)
        setparameters!(req, parameters)
    end
    resp = dorequest(req, skip404 = skip404, verbose = verbose)
    ret = parseresponse(resp)
    return ret
end

function getparameters(request::Request)
    url = request.url
    !occursin(r"\?", url) && return String[]
    paramstring = match(r"(?<=\?).*", url)
    params = string.(split(paramstring.match, '&'))
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

parsedict(d)=["$k=$v" for (k,v) in d]
setparameters!(request::Request, parameters::Dict; add::Bool = false) = 
    setparameters!(request, parsedict(parameters); add=add)

function setparameter!(request::Request, which::String, value)
    which = strip(which); value = strip(string(value))
    params = getparameters(request)
    paramnames = [match(r".*(?=\=)", param).match for param in params]
    idx = findlast(x -> x == which, paramnames)
    newparam = string(which, '=', value)
    idx === nothing ? push!(params, newparam) : (params[idx] = newparam)
    setparameters!(request, params)
end

setparameter!(request::Request, name_val::Pair) = setparameter!(request, name_val.first, name_val.second)

function writestate(request::Request, file = "state.jsonl"; append = false)
    mode = append ? "a+" : "w+"
    open(file, mode) do io
        JSON.print(io, request.state)
        write(io, '\n')
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

function requestprotector(response::HTTP.Messages.Response,
                        request::Request; verbose = false)
    code = response.status
    code != 200 && verbose && println("Code: $code")
    if code ∈ 400:499
        code == 401 && newtoken!(request.token)
        ratelimitprotect(response, verbose = verbose)
        tokenprotector!(request.token)
    elseif code ∈ 500:599
        sleeptime = request.sleeptime
        verbose && println("Chartmetric server error. Sleeping for $sleeptime seconds")
        sleep(sleeptime)
    elseif code ∉ 200:399
        ratelimitprotect(response, verbose = verbose)
    end # if
    return code
end # fun
