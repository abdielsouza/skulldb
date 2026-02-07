defmodule Skulldb.HTTP.SwaggerUI do
  @moduledoc """
  Swagger UI HTTP handler for SkullDB API documentation.
  Serves the OpenAPI specification and Swagger UI interface.
  """

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  # Serve Swagger UI at root
  match "" do
    swagger_ui_html(conn)
  end

  # Serve OpenAPI JSON specification
  match "openapi.json" do
    spec = Skulldb.HTTP.Spec.spec()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(spec))
  end

  # Serve Swagger UI assets from CDN
  match "swagger-ui.css" do
    redirect_to_cdn(conn, "swagger-ui.css")
  end

  match "swagger-ui.js" do
    redirect_to_cdn(conn, "swagger-ui.js")
  end

  match "swagger-ui-bundle.js" do
    redirect_to_cdn(conn, "swagger-ui-bundle.js")
  end

  match "swagger-ui-standalone-preset.js" do
    redirect_to_cdn(conn, "swagger-ui-standalone-preset.js")
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp swagger_ui_html(conn) do
    html = """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <title>SkullDB API Documentation</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.15.5/swagger-ui.min.css">
        <style>
          html {
            box-sizing: border-box;
            overflow: -moz-scrollbars-vertical;
            overflow-y: scroll;
          }
          *,
          *:before,
          *:after {
            box-sizing: inherit;
          }
          body {
            margin: 0;
            padding: 0;
          }
          .topbar {
            background-color: #fafafa;
            padding: 10px 0;
            border-bottom: 1px solid #e0e0e0;
          }
          .topbar-title {
            margin-left: 20px;
            font-size: 20px;
            font-weight: bold;
            color: #333;
          }
        </style>
      </head>
      <body>
        <div id="swagger-ui"></div>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.15.5/swagger-ui.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.15.5/swagger-ui-bundle.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.15.5/swagger-ui-standalone-preset.min.js"></script>
        <script>
          window.onload = function() {
            const ui = SwaggerUIBundle({
              url: "/api/docs/openapi.json",
              dom_id: '#swagger-ui',
              presets: [
                SwaggerUIBundle.presets.apis,
                SwaggerUIStandalonePreset
              ],
              layout: "StandaloneLayout",
              deepLinking: true,
              plugins: [
                SwaggerUIBundle.plugins.DownloadUrl
              ]
            });
            window.ui = ui;
          };
        </script>
      </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html; charset=utf-8")
    |> send_resp(200, html)
  end

  defp redirect_to_cdn(conn, asset) do
    cdn_url = "https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/4.15.5/#{asset}"

    conn
    |> put_resp_header("location", cdn_url)
    |> send_resp(302, "")
  end
end
