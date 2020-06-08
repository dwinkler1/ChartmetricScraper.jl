function writeresponse(response::HTTP.Messages.Response)
#TODO

end

function parseresponse(response::HTTP.Messages.Response)
    bod = response.body
    code = response.status
    ret_dict = JSON.parse(String(bod))
    if code ∉ 200:399
        ret_dict["code"] = code
        ret_dict["url"] = response.request.target
    end
    return ret_dict
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

function ratelimitprotect(response::HTTP.Messages.Response)
    headers = Dict(response.headers)
    remaining = haskey(headers, "X-RateLimit-Remaining") ? parse(Int, headers["X-RateLimit-Remaining"]) : 0
    if remaining < 1
        resetin =  haskey(headers, "X-RateLimit-Reset") ? parse(Int, headers["X-RateLimit-Reset"]) - time() : 60
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
