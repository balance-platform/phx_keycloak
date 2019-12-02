defmodule PhxKeycloak.UseCases.KeycloakAuthorizeUrl do
  @moduledoc false

  require Logger

  def call(params) do
    query = %{
      client_id: params[:client_id],
      redirect_uri: params[:redirect_uri],
      response_type: "code"
    }

    encoded_query = URI.encode_query(query)

    uri = URI.parse(params[:site])

    path = Enum.join(["/auth/realms", params[:realm], "protocol", "openid-connect/auth"], "/")

    URI.to_string(%{uri | query: encoded_query, path: path})
  end
end
