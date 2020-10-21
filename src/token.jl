
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
    newtoken!(token::Token; verbose = false)

Refreshes an existing request `Token`

# Arguments:
- `token` : the request `Token`
- `verbose=false` : print a message when a new token is requested
"""
function newtoken!(token::Token; verbose = false)
    verbose && println("Requesting new Token...")
    token_dict, expires = tokenrequest(token.refreshtoken, token.maxtries)
    token.token = token_dict["token"]
    token.expires = expires
    token.scope = token_dict["scope"]
    return token
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
            trial >= (maxtries - 2) && println(resp); sleep(60)
            trial >= (maxtries - 1) && @error "Could not get token"
        end
    end
    resp.status > 500 && return nothing
    token_dict = JSON.parse(String(resp.body))
    expires = time + Dates.Second(token_dict["expires_in"])
    return (token_dict, expires)
end
