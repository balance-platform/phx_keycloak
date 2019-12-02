defmodule PhxKeycloak.UseCases.KeycloakUserClaims do
  @moduledoc """
  Получение информации о пользователе с помощью его access_token'a
  """

  @headers [{"Content-Type", "application/x-www-form-urlencoded"}]

  def call(nil, _params) do
    nil
  end

  def call(access_token, params) do
    data = [
      access_token: access_token,
      client_secret: params[:client_secret]
    ]

    resp = HTTPoison.post(keycloak_userinfo_uri(params), {:form, data}, @headers)

    case resp do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, data} -> data
          _otherwise -> %{}
        end

      _otherwise ->
        nil
    end
  end

  defp keycloak_userinfo_uri(params) do
    [
      params[:site],
      "auth/realms",
      params[:realm],
      "protocol/openid-connect/userinfo"
    ]
    |> Enum.join("/")
  end
end
