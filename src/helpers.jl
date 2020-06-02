
function readstate!()
# TODO
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
function buildrequesturl(url)
    base = "https://api.chartmetric.com/api/"
    urls = join(url, '/')
    url_req =  base * urls
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

function parsecmdate(date::String)
    date_tmp = string(SubString(date, 1:25))
    return parse(Dates.DateTime, date_tmp, Dates.RFC1123Format)
end
