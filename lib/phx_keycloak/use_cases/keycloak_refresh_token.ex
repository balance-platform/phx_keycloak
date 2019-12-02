defmodule PhxKeycloak.UseCases.KeycloakRefreshToken do
  @moduledoc """
  Обновление access_token'a пользователя
  """
  require Logger
  @headers [{"Content-Type", "application/x-www-form-urlencoded"}]

  def call(nil, _params) do
    {nil, nil}
  end

  def call(refresh_token, params) do
    data = [
      refresh_token: refresh_token,
      client_id: params[:client_id],
      client_secret: params[:client_secret],
      grant_type: "refresh_token"
    ]

    resp = HTTPoison.post(keycloak_refresh_token_uri(params), {:form, data}, @headers)

    case resp do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        result = Jason.decode!(body)
        {result["access_token"], result["refresh_token"]}

      otherwise ->
        Logger.warn(
          "UseCases.KeycloakRefreshToken: Ошибка обновления токена, #{inspect(otherwise)}"
        )

        {nil, nil}
    end
  end

  defp keycloak_refresh_token_uri(params) do
    [
      params[:site],
      "auth/realms",
      params[:realm],
      "protocol/openid-connect/token"
    ]
    |> Enum.join("/")
  end
end
