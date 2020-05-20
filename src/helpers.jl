
mutable struct Token
    token::String
    expires::DateTime
    scope::String
    refreshtoken::String
    maxtries::Int
end

"""
    Token(refreshtoken::String)

Returns a `Token` that can be used for requests.

# Arguments:
- `refreshtoken` : Refreshtoken associated with your Chartmetric account.
"""
function Token(refreshtoken::String,  maxtries::Int = 5)
    @assert maxtries > 0 "maxtries have to be positive"
    token_dict, expires = tokenrequest(refreshtoken, maxtries)
    return Token(token_dict["token"],
                expires,
                token_dict["scope"],
                token_dict["refresh_token"],
                maxtries)
end


"""
    Request(token::Token, url::String[, maxtries::Int, sleeptime::Number])
    Request(refreshtoken::String, url::String[, maxtries::Int, sleeptime::Number])

Creates a `Request` to be used with `dorequest(...)`

# Arguments:
- `token` : the request `Token`
- `url` : Chartmetric URL to be requested
- [`maxtries`] : maximum number of tries to get the request (default = `token.maxtries`)
- [`sleeptime`] : Time to wait after server error in seconds (default = 600)
- `refreshtoken` : Chartmetric refreshtoken associated with your account
"""
struct Request
    token::Token
    url::String
    maxtries::Int
    sleeptime::Number
    function Request(token::Token, url, maxtries = nothing, sleeptime = 600)
        tokenprotector!(token)
        @assert sleeptime >= 0 "sleeptime cannot be negative"
        @assert maxtries > 0 "maxtries must be positive"
        maxtries === nothing && (maxtries = token.maxtries)
        return new(token, url, maxtries, sleeptime)
    end # fun
end # struct

Request(refreshtoken::String, url, maxtries, sleeptime) = Request(Token(refreshtoken), url, maxtries)

# Exported

"""
    newtoken!(token::Token)

Refreshes an existing request `Token`

# Arguments:
- `token` : the request `Token`
"""
function newtoken!(token::Token)
    token_dict, expires = tokenrequest(token.refreshtoken, token.maxtries)
    token.token = token_dict["token"]
    token.expires = expires
    token.scope = token_dict["scope"]
    return token
end

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


function offsetparser(parameters, from, to, limit)
    all_parameters = []
    for iter in from:limit:to
        off = iter + 1
        push!(all_parameters, vcat(parameters, ["limit=$limit", "offset=$off"]))
    end
    return all_parameters
end

function parseresponse(response::HTTP.Messages.Response)
    bod = response.body
    text = JSON.parse(String(bod))
    flattenlists!(text)
    df = vcat([DataFrame(row) for row in text["obj"]]...)
    return df
end

function flattenlists!(responsedict)
    for dict in responsedict["obj"]
        for (key, value) in dict
            dict[key] = typeof(value) <: Array ? join(value, ", ") : value
        end
    end
end

# Not exported
function buildrequest(url, parameters)
    base = "https://api.chartmetric.com/api/"
    urls = join(url, "/")
    parameters = parameters[parameters.!==nothing]
    params = length(parameters) > 0 ?  '?' * join(parameters, "&") : ""
    url_req =  base * urls * params
    return url_req
end

function requestprotector(response::HTTP.Messages.Response,
                        token::Token)
    code = response.status

    if code ∈ 400:499
        ratelimitprotect(response)
        tokenprotector!(token)
    elseif code ∈ 500:599
        sleeptime = token.sleeptime
        println("Chartmetric server error. Sleeping for $sleeptime seconds")
        sleep(sleeptime)
    elseif code ∉ 200:399
        ratelimitprotect(response)
    end # if
    return code
end # fun

function ratelimitprotect(response::HTTP.Messages.Response)
    headers = Dict(response.headers)
    remaining = parse(Int, headers["X-RateLimit-Remaining"])
    if remaining < 1
        resetin =  parse(Int, headers["X-RateLimit-Reset"]) - time()
        sleepfor = maximum([0.1, resetin])
        println("Protecting rate limit")
        sleep((sleepfor + 5))
    end
    return nothing
end

function tokenprotector!(token::Token)
    token.expires <= (Dates.now() + Dates.Minute(1)) && newtoken!(token)
    return token
end

function tokenrequest(refreshtoken::String, maxtries = 5)
    header = ["Content-Type" => "application/json"]
    body = """{"refreshtoken":"$refreshtoken"}"""
    time = Dates.now()
    req = :(HTTP.request("POST",
            "https://api.chartmetric.com/api/token",
            $header, $body ,
            retry = true,
            status_exception = false))
    resp = eval(req)
    if resp.status ∉ 200:399
        for trial in 1:(maxtries-1)
            resp = eval(req)
            resp.status ∈ 200:399 && break
            trial >= (maxtries - 2) && sleep(60)
            trial >= (maxtries - 1) && @error "Could not get token"
        end
    end
    token_dict = JSON.parse(String(resp.body))
    expires = time + Dates.Second(token_dict["expires_in"])
    return (token_dict, expires)
end

function parsecmdate(date::String)
    date_tmp = string(SubString(date, 1:25))
    return parse(Dates.DateTime, date_tmp, Dates.RFC1123Format)
end
