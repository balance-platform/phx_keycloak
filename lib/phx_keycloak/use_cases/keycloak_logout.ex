defmodule PhxKeycloak.UseCases.KeycloakLogout do
  @moduledoc """
  Сброс сессии пользователя в Keycloak
  """
  @headers [{"Content-Type", "application/x-www-form-urlencoded"}]

  def call(nil, _params) do
    :ok
  end

  def call(refresh_token, params) do
    data = [
      refresh_token: refresh_token,
      client_secret: params[:client_secret],
      client_id: params[:client_id]
    ]

    HTTPoison.post(keycloak_refresh_token_uri(params), {:form, data}, @headers)

    :ok
  end

  defp keycloak_refresh_token_uri(params) do
    [
      params[:site],
      "auth/realms",
      params[:realm],
      "protocol/openid-connect/logout"
    ]
    |> Enum.join("/")
  end
end
