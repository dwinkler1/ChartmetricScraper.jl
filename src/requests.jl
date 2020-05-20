
function albumrequest(token::Token, variable, id, maxtries = 5;
        type=nothing, platform = nothing, status = nothing,
        parameters::Vector)
    allowedvars = ["charts", "get-ids", "playlists", "stats", "tracks", "tunefind", "metadata"]
    variable = lowercase(variable)
    variable ∈ allowedvars || @warn "Variable is unknown. Trying to parse..."
    url = ["album"]
    id = string(id)
    if variable == "charts"
        required =  [id, type, variable]
        any(x -> x == nothing, required) && @error string("Missing required argument: type")
        append!(url, required)
    elseif variable == "get-ids"
        required = [type, id, variable]
        any(x -> x == nothing, required) && @error string("Missing required argument: type")
        append!(url, required)
    elseif variable == "metadata"
        push!(url, id)
    elseif variable == "playlists"
        required = [id, platform, status, variable]
        any(x -> x == nothing, required) && @error string("Missing required argument(s): platform, status")
        append!(url, required)
    elseif variable == "stats"
        required = [id, platform, variable]
        any(x -> x == nothing, required) && @error string("Missing required argument: platform")
        append!(url, required)
    elseif variable ∈ ["tracks", "tunefind"]
        append!(url,  [id, variable])
    else
        vars_all = [id, type, platform, status, variable]
        vars_provided = vars_all[vars_all .!== nothing]
        append!(url, vars_provided)
        println(string("Parsed URL: ", buildrequest(url, parameters)))
    end
    url_req = buildrequest(url, parameters)
    req = Request(token, url_req, maxtries)
    return req
end

function curatorrequest(token::Token, variable, maxtries = 5;
            platform = nothing, id = nothing, parameters::Vector = [nothing])
            # TODO input checks
            @assert platform !== nothing
            url = ["curator"]
            if variable == "metadata"
                @assert id !== nothing
                append!(url, [platform, id])
            elseif variable == "lists"
                append!(url, [platform, variable])
            elseif variable == "playlists"
                @assert id !== nothing
                append!(url, [platform, id, variable])
            else
                vars_all = [platform, id, variable]
                vars_provided = vars_all[vars_all .!== nothing]
                append!(url, vars_provided)
                println(string("Parsed URL: ", buildrequest(url, parameters)))
            end
            url_req = buildrequest(url, parameters)
            req = Request(token, url_req, maxtries)
            return req
end

function playlistrequest(token::Token, variable, maxtries = 5;
            id = nothing, platform = nothing, type = nothing, span = nothing,
            parameters::Vector)
            allowedvars = ["metadata", "playlist-evolution", "journey-progression", "lists", "snapshot", "stats", "tracks"]
            variable = lowercase(variable)
            variable ∈ allowedvars || @warn "Variable is unknown. Trying to parse..."
            url = ["playlist"]
            if variable == "metadata"
                @assert platform !== nothing && id !== nothing
                id = string(id)
                append!(url, [platform, id])
            elseif variable == "playlist-evolution"
                @assert type !== nothing && id !== nothing
                id = string(id)
                append!(url, ["by", type, id, variable])
            elseif variable == "journey-progression"
                @assert platform !== nothing && id !== nothing && type !== nothing
                id = string(id)
                append!(url, [platform, id, variable, type])
            elseif variable == "lists"
                @assert platform !== nothing
                append!(url, [platform, variable])
            elseif variable == "snapshot"
                @assert platform !== nothing && id !== nothing
                id = string(id)
                append!(url, [platform, id, variable])
            elseif variable == "stats"
                @assert platform !== nothing && id !== nothing
                id = string(id)
                append!(url, [platform, id, variable])
            elseif variable == "tracks"
                @assert platform !== nothing && id !== nothing && span !== nothing
                id = string(id)
                append!(url, [platform, id, span, variable])
            else
                id !== nothing && (id = string(id))
                vars_all = [platform, id, span, variable, type]
                vars_provided = vars_all[vars_all .!== nothing]
                append!(url, vars_provided)
                println(string("Parsed URL: ", buildrequest(url, parameters)))
            end
            url_req = buildrequest(url, parameters)
            req = Request(token, url_req, maxtries)
            return req
end
