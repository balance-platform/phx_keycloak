defmodule PhxKeycloak.UseCases.KeycloakUserClaimsTest do
  use ExUnit.Case
  alias PhxKeycloak.UseCases.KeycloakUserClaims
  import Mock

  @fake_response %{
    "email" => "admin@admin.ru",
    "email_verified" => false,
    "family_name" => "adminovich",
    "given_name" => "admin",
    "name" => "admin adminovich",
    "preferred_username" => "admin",
    "sub" => "03dfc30d-e70c-4f2f-9343-d73753f080d5"
  }

  @params %{
    realm: "test_master",
    site: "http://localhost:8080",
    client_id: "cronos_client",
    client_secret: "secret",
    redirect_uri: "http://localhost:4000/callback"
  }

  test "#call/2 - был передан nil" do
    assert nil == KeycloakUserClaims.call(nil, @params)
  end

  test "#call/2- был передан refresh_token" do
    with_mock HTTPoison,
      post: fn _url, _data, _headers ->
        {:ok, %HTTPoison.Response{status_code: 200, body: Jason.encode!(@fake_response)}}
      end do
      assert %{
               "email" => "admin@admin.ru",
               "email_verified" => false,
               "family_name" => "adminovich",
               "given_name" => "admin",
               "name" => "admin adminovich",
               "preferred_username" => "admin",
               "sub" => "03dfc30d-e70c-4f2f-9343-d73753f080d5"
             } == KeycloakUserClaims.call("access_token", @params)

      assert_called(
        HTTPoison.post(
          "http://localhost:8080/auth/realms/test_master/protocol/openid-connect/userinfo",
          {:form, [access_token: "access_token", client_secret: "secret"]},
          [{"Content-Type", "application/x-www-form-urlencoded"}]
        )
      )
    end
  end
end
