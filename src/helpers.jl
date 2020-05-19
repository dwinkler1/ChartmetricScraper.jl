
"""
    gettoken(refreshtoken::String)
"""
function gettoken(refreshtoken::String)
    header = "Content-Type" => "application/json"
    data = "refreshtoken" => refreshtoken
    HTTP.request(:POST,
        "https://api.chartmetric.com/api/token",
        header, data)
end
