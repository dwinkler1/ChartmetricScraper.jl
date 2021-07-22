function search(tkn, query; limit = 10, offset = 0, type = "all")
    @assert type ∈  ["all", "artists", "tracks", "playlists", "curators", "albums", "stations", "cities"]
    ret = getparsed(tkn, ["search"], ["limit=$limit", "offset=$offset", "type=$type"])
    if haskey(ret, "obj")
        return ret["obj"]
    else
        return ret
    end
end

function albumrequest(token::Token, variable, id, maxtries = 5;
        type=nothing, platform = nothing, status = nothing,
        parameters::Vector{String})
    allowedvars = ["charts", "get-ids", "playlists", "stats", "tracks", "tunefind", "metadata"]
    variable = lowercase(variable)
    variable ∈ allowedvars || @warn "Variable is unknown. Trying to parse..."
    path = ["album"]
    id = string(id)
    if variable == "charts"
        required =  [id, type, variable]
        any(x -> x === nothing, required) && @error string("Missing required argument: type")
        append!(path, required)
    elseif variable === "get-ids"
        required = [type, id, variable]
        any(x -> x === nothing, required) && @error string("Missing required argument: type")
        append!(path, required)
    elseif variable === "metadata"
        push!(path, id)
    elseif variable == "playlists"
        required = [id, platform, status, variable]
        any(x -> x === nothing, required) && @error string("Missing required argument(s): platform, status")
        append!(path, required)
    elseif variable == "stats"
        required = [id, platform, variable]
        any(x -> x === nothing, required) && @error string("Missing required argument: platform")
        append!(path, required)
    elseif variable ∈ ["tracks", "tunefind"]
        append!(path,  [id, variable])
    else
        vars_all = [id, type, platform, status, variable]
        vars_provided = vars_all[vars_all .!== nothing]
        append!(path, vars_provided)
        println(string("Parsed URL: ", buildrequesturl(path)))
    end
    url_req = buildrequesturl(path)
    req = Request(token, url_req, maxtries)
    setparameters!(req, parameters)
    return req
end

function curatorrequest(token::Token, variable, maxtries = 5;
            platform = nothing, id = nothing, parameters::Vector{String})
            # TODO input checks
            @assert platform !== nothing
            path = ["curator"]
            if variable == "metadata"
                @assert id !== nothing
                append!(path, [platform, id])
            elseif variable == "lists"
                append!(path, [platform, variable])
            elseif variable == "playlists"
                @assert id !== nothing
                append!(path, [platform, id, variable])
            else
                vars_all = [platform, id, variable]
                vars_provided = vars_all[vars_all .!== nothing]
                append!(path, vars_provided)
                println(string("Parsed URL: ", buildrequesturl(path)))
            end
            url_req = buildrequesturl(path)
            req = Request(token, url_req, maxtries)
            setparameters!(req, parameters)
            return req
end

function playlistrequest(token::Token, variable, maxtries = 5;
            id = nothing, platform = nothing, type = nothing, span = nothing,
            parameters::Vector{String} = [""])
            allowedvars = ["metadata", "playlist-evolution", "journey-progression", "lists", "snapshot", "stats", "tracks"]
            variable = lowercase(variable)
            variable ∈ allowedvars || @warn "Variable is unknown. Trying to parse..."
            path = ["playlist"]
            if variable == "metadata"
                @assert platform !== nothing && id !== nothing
                id = string(id)
                append!(path, [platform, id])
            elseif variable == "playlist-evolution"
                @assert type !== nothing && id !== nothing
                id = string(id)
                append!(path, ["by", type, id, variable])
            elseif variable == "journey-progression"
                @assert platform !== nothing && id !== nothing && type !== nothing
                id = string(id)
                append!(path, [platform, id, variable, type])
            elseif variable == "lists"
                @assert platform !== nothing
                append!(path, [platform, variable])
            elseif variable == "snapshot"
                @assert platform !== nothing && id !== nothing
                id = string(id)
                append!(path, [platform, id, variable])
            elseif variable == "stats"
                @assert platform !== nothing && id !== nothing
                id = string(id)
                append!(path, [platform, id, variable])
            elseif variable == "tracks"
                @assert platform !== nothing && id !== nothing && span !== nothing
                id = string(id)
                append!(path, [platform, id, span, variable])
            else
                id !== nothing && (id = string(id))
                vars_all = [platform, id, span, variable, type]
                vars_provided = vars_all[vars_all .!== nothing]
                append!(path, vars_provided)
                println(string("Parsed URL: ", buildrequesturl(path)))
            end
            url_req = buildrequesturl(path)
            req = Request(token, url_req, maxtries)
            setparameters!(req, parameters)
            return req
end
