defmodule PhxKeycloak.UseCases.KeycloakLogoutTest do
  use ExUnit.Case
  alias PhxKeycloak.UseCases.KeycloakLogout
  import Mock

  @params %{
    realm: "test_master",
    site: "http://localhost:8080",
    client_id: "cronos_client",
    client_secret: "secret",
    redirect_uri: "http://localhost:4000/callback"
  }

  test "#call/2 - был передан nil" do
    assert :ok = KeycloakLogout.call(nil, @params)
  end

  test "#call/2 - был передан refresh_token" do
    with_mock HTTPoison,
      post: fn _url, _data, _headers ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "Нас не волнует какой тут ответ"}}
      end do
      assert :ok = KeycloakLogout.call("refresh_token", @params)

      assert_called(
        HTTPoison.post(
          "http://localhost:8080/auth/realms/test_master/protocol/openid-connect/logout",
          {:form,
           [
             refresh_token: "refresh_token",
             client_secret: "secret",
             client_id: "cronos_client"
           ]},
          [{"Content-Type", "application/x-www-form-urlencoded"}]
        )
      )
    end
  end
end
