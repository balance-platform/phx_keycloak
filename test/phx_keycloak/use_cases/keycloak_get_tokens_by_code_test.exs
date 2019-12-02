defmodule PhxKeycloak.UseCases.KeycloakGetTokensByCodeTest do
  use ExUnit.Case
  alias PhxKeycloak.UseCases.KeycloakGetTokensByCode
  import Mock

  @fake_response %{
    "access_token" => "new_access_token",
    "expires_in" => 60,
    "refresh_expires_in" => 1800,
    "refresh_token" => "new_refresh_token",
    "token_type" => "bearer",
    "not-before-policy" => 0,
    "session_state" => "session_state",
    "scope" => "email profile"
  }

  @params %{
    realm: "test_master",
    site: "http://localhost:8080",
    client_id: "cronos_client",
    client_secret: "secret",
    redirect_uri: "http://localhost:4000/callback"
  }

  test "#call/2 - был передан code" do
    with_mock HTTPoison,
      post: fn _url, _data, _headers ->
        {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(@fake_response)}}
      end do
      assert {"new_access_token", "new_refresh_token"} =
               KeycloakGetTokensByCode.call("code", @params)

      assert_called(
        HTTPoison.post(
          "http://localhost:8080/auth/realms/test_master/protocol/openid-connect/token",
          {:form,
           [
             client_secret: "secret",
             redirect_uri: "http://localhost:4000/callback",
             grant_type: "authorization_code",
             client_id: "cronos_client",
             code: "code"
           ]},
          [{"Content-Type", "application/x-www-form-urlencoded"}]
        )
      )
    end
  end
end
