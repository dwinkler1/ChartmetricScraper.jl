using Documenter, ChartmetricScraper

makedocs(
    modules = [ChartmetricScraper],
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", nothing) == "true"),
    authors = "Daniel Winkler",
    sitename = "ChartmetricScraper.jl",
    pages = Any["index.md"]
    # strict = true,
    # clean = true,
    # checkdocs = :exports,
)

deploydocs(
    repo = "github.com/danielw2904/ChartmetricScraper.jl.git",
    push_preview = true
)
