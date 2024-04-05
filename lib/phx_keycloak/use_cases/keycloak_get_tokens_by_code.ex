defmodule PhxKeycloak.UseCases.KeycloakGetTokensByCode do
  @moduledoc """
  Получение токенов пользователя при помощи полученного ранее кода
  """
  require Logger
  @headers [{"Content-Type", "application/x-www-form-urlencoded"}]

  def call(nil, _params) do
    {nil, nil}
  end

  def call(code, params) do
    data = [
      client_secret: params[:client_secret],
      redirect_uri: params[:redirect_uri],
      grant_type: "authorization_code",
      client_id: params[:client_id],
      code: code
    ]

    resp = HTTPoison.post(keycloak_refresh_token_uri(params), {:form, data}, @headers)

    case resp do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        result = Jason.decode!(body)
        {result["access_token"], result["refresh_token"]}

      otherwise ->
        Logger.warning(
          "UseCases.KeycloakGetTokensByCode: Ошибка получения токенов, #{inspect(otherwise)}"
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
