defmodule PhxKeycloak.UseCases.KeycloakAuthorizeUrlTest do
  use ExUnit.Case
  alias PhxKeycloak.UseCases.KeycloakAuthorizeUrl

  @params %{
    realm: "test_master",
    site: "http://localhost:8080",
    client_id: "cronos_client",
    client_secret: "secret",
    redirect_uri: "http://localhost:4000/callback"
  }

  test "#call - генерирует ожидаемую ссылку" do
    assert KeycloakAuthorizeUrl.call(@params) ==
             "http://localhost:8080/auth/realms/test_master/protocol/openid-connect/auth?client_id=cronos_client&redirect_uri=http%3A%2F%2Flocalhost%3A4000%2Fcallback&response_type=code"
  end
end
