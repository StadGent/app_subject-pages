defmodule Dispatcher do
  use Matcher
  import Plug.Conn
  define_accept_types [
    json: [ "application/json", "application/vnd.api+json" ],
    html: [ "text/html", "application/xhtml+html" ],
    sparql: ["application/sparql-results+json",
             "application/sparql-results+xml",
            ],
    rdf: [
      "application/ld+json",
      "application/rdf+xml",
      "text/turtle",
      "application/n-triples"
    ]
  ]

  @any %{}
  @json %{ accept: %{ json: true } }
  @html %{ accept: %{ html: true } }

  define_layers [ :redirects, :static, :api_services, :virtuoso,  :fallback, :not_found ]

  # REDIRECTS
  # this is a quick hack because the frontend (metis) expects the true uri (with /id) but that goes to cool-uris.
  # another option is to have these view urls in the data
  get "/data/data-processing/activities/*uuid", %{ layer: :redirects, accept: %{ html: true } } do
    base_url = System.get_env("BASE_URI") || "https://stad.gent"
    resource_url = "#{base_url}/id/data-processing/activities/#{Enum.join(uuid, "/")}"
    encoded_resource = URI.encode_www_form(resource_url)

    # Preserve embed parameter if present
    embed_param = case conn.query_string |> URI.decode_query() |> Map.get("embed") do
      nil -> ""
      embed_value -> "&embed=#{URI.encode_www_form(embed_value)}"
    end

    redirect_url = "/data/view/verwerkings-activiteit?resource=#{encoded_resource}#{embed_param}"

    conn
    |> put_resp_header("location", redirect_url)
    |> send_resp(302, "")
  end

 # frontend
  get "/data/assets/*path", %{ layer: :static } do
    forward conn, path, "http://frontend/data/assets/"
  end

  get "/data/@appuniversum/*path", %{ layer: :static } do
    forward conn, path, "http://frontend/data/@appuniversum/"
  end

  get "/data/index.html", %{ layer: :static } do
    forward conn, [], "http://frontend/data/index.html"
  end

  get "/data/view/*path", %{ layer: :static, accept: %{ html: true } } do
    forward conn, [] , "http://frontend/data/index.html"
  end

  match "/data/crm/agents/*path", %{ layer: :static, accept: %{ html: true } } do
    forward conn, [], "http://frontend/data/index.html"
  end

  match "/data/turtle/*path", %{ layer: :static } do
    forward conn, path, "http://virtuoso:8890/data/turtle/id/"
  end

  # API SERVICES
  match "/data/resource-labels/*path", %{ layer: :api_services, accept: %{ json: true } } do
    forward conn, path, "http://resource-labels/"
  end

  get "/data/uri-info/*path", %{ layer: :api_services, accept: %{ json: true } } do
    forward conn, path, "http://uri-info/"
  end

  get "/data/*path", %{ layer: :api_services, accept: %{ rdf: true } } do
    base_url = System.get_env("BASE_URI") || "https://stad.gent"
    resource_url = "#{base_url}/id/#{Enum.join(path, "/")}"
    encoded_resource = URI.encode_www_form(resource_url)
    forward conn, ["describe?uri=#{encoded_resource}"], "http://uri-info/"
  end

  get "/data/*path", %{ layer: :api_services } do
    # This is in the api_services layer because browsers have broad accept headers
    # more specific headers will match the more specific targeted routes
    forward conn, path, "http://virtuoso:8890/data/"
  end


  # VIRTUOSO
  match "/conductor/*path", %{ layer: :virtuoso } do
    forward conn, path, "http://virtuoso:8890/conductor/"
  end

  match "/sparql/*path", %{ layer: :virtuoso } do
    forward conn, path, "http://virtuoso:8890/sparql/"
  end

  match "/sparql-auth", %{ layer: :virtuoso } do
    forward conn, [], "http://virtuoso:8890/sparql-auth"
  end

  match "/sparql-graph-crud-auth/*path", %{ layer: :virtuoso } do
    forward conn, path, "http://virtuoso:8890/sparql-graph-crud-auth"
  end


  # fallback
  match "/*_", %{ layer: :not_found } do
    send_resp( conn, 404, "Route not found.  See config/dispatcher.ex" )
  end

end
