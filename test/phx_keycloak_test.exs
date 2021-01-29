defmodule PhxKeycloakTest do
  use ExUnit.Case
  import Mock

  alias PhxKeycloak.UseCases.KeycloakAuthorizeUrl
  alias PhxKeycloak.UseCases.KeycloakGetTokensByCode
  alias PhxKeycloak.UseCases.KeycloakLogout
  alias PhxKeycloak.UseCases.KeycloakRefreshToken
  alias PhxKeycloak.UseCases.KeycloakUserClaims

  defmodule PhoenixKeycloakModule do
    use PhxKeycloak,
      realm: "test_master",
      site: "http://localhost:8080",
      client_id: "cronos_client",
      client_secret: "secret",
      redirect_uri: "http://localhost:4000/callback",
      expected_group: "admin"
  end

  @params %{
    realm: "test_master",
    site: "http://localhost:8080",
    client_id: "cronos_client",
    client_secret: "secret",
    redirect_uri: "http://localhost:4000/callback"
  }

  setup_with_mocks([
    {KeycloakAuthorizeUrl, [], [call: fn _params -> :we_dont_care end]},
    {KeycloakGetTokensByCode, [], [call: fn _code, _params -> :we_dont_care end]},
    {KeycloakLogout, [], [call: fn _token, _params -> :we_dont_care end]},
    {KeycloakRefreshToken, [], [call: fn _token, _params -> :we_dont_care end]},
    {KeycloakUserClaims, [], [call: fn _token, _params -> :we_dont_care end]}
  ]) do
    {:ok, %{}}
  end

  test "#refresh_token" do
    assert :we_dont_care == PhoenixKeycloakModule.refresh_token("token")
    assert_called(KeycloakRefreshToken.call("token", @params))
  end

  test "#logout" do
    assert :we_dont_care == PhoenixKeycloakModule.logout("token")
    assert_called(KeycloakLogout.call("token", @params))
  end

  test "#get_user_claims" do
    assert :we_dont_care == PhoenixKeycloakModule.get_user_claims("token")
    assert_called(KeycloakUserClaims.call("token", @params))
  end

  test "#get_tokens_by_code" do
    assert :we_dont_care == PhoenixKeycloakModule.get_tokens_by_code("code")
    assert_called(KeycloakGetTokensByCode.call("code", @params))
  end

  test "#authorize_url" do
    assert :we_dont_care == PhoenixKeycloakModule.authorize_url()
    assert_called(KeycloakAuthorizeUrl.call(@params))
  end
end
