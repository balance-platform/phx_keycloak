defmodule PhxKeycloak do
  @moduledoc """
  # Настройка 

  ## Главный модуль

  Сначала необходимо определить модуль, который будет отвечать за авторизацию по Keycloak

  Обязательные параметры:

    * realm - realm ID

    * site - endpoint Keycloak

    * client_id - идентификатор клиента Keycloak

    * client_secret - секретный токен клиента

    * redirect_uri - callback адрес вашего приложения

  ```elixir
    defmodule MyAppWeb.Keycloak do
      use PhxKeycloak, realm: "cronos",
        site: "http://localhost:8080",
        client_id: "cronos_check_app",
        client_secret: "7c9fb08e-2d11-4921-bc02-cc21c92b6139",
        redirect_uri: "http://localhost:4000/callback"
    end
  ```

  ## Plug'и
  Теперь нам доступны следующие Plug'и:

    * MyAppWeb.Keycloak.Plugs.RefreshUserTokenPlug - Обновление токена

    * MyAppWeb.Keycloak.Plugs.GetClaimsPlug - получение информации о пользователе

    * MyAppWeb.Keycloak.Plugs.RedirectUnauthorizedUserToLoginPlug, redirect_route: "/login" - редирект неавторизованного пользователя на указанный адрес

  ## Контроллер

  Объявим контроллер, который будет логинить и разлогинить пользователя:
  ```elixir
  defmodule MyAppWeb.AuthorizeController do
    use MyAppWeb, :controller
    alias MyAppWeb.Keycloak

    def login(conn, _) do
      redirect(conn, external: Keycloak.authorize_url())
    end

    def logout(conn, _) do
      refresh_token = get_session(conn, :refresh_token)

      Keycloak.logout(refresh_token)

      conn
      |> clear_session()
      |> redirect(to: "/")
    end

    def callback(conn, %{"code" => code}) do
      {_access_token, refresh_token} = Keycloak.get_tokens_by_code(code)

      conn
      |> put_session(:refresh_token, refresh_token)
      |> redirect(to: "/")
    end
  end
  ```

  ## Router

  В MyAppWeb.Router добавляем следующие pipeline'ы: 

  ```elixir
  ...
  pipeline :keycloak do
    plug Keycloak.Plugs.RefreshUserTokenPlug
    plug Keycloak.Plugs.GetClaimsPlug
  end

  pipeline :auth_or_redirect do
    plug Keycloak.Plugs.RedirectUnauthorizedUserToLoginPlug, redirect_route: "/login"
  end
  ...
  ```

  Теперь роутер должен выглядеть примерно так:

  ```elixir
  defmodule MyAppWeb.Router do
    use MyAppWeb, :router

    alias MyAppWeb.Keycloak

    pipeline :browser do
      plug :accepts, ["html"]
      plug :fetch_session
      plug :fetch_flash
      plug :protect_from_forgery
      plug :put_secure_browser_headers
    end

    pipeline :keycloak do
      plug Keycloak.Plugs.RefreshUserTokenPlug
      plug Keycloak.Plugs.GetClaimsPlug
    end

    pipeline :auth_or_redirect do
      plug Keycloak.Plugs.RedirectUnauthorizedUserToLoginPlug, redirect_route: "/login"
    end

    pipeline :api do
      plug :accepts, ["json"]
    end

    scope "/", MyAppWeb do
      pipe_through :browser
      pipe_through :keycloak
      pipe_through :auth_or_redirect

      # ...my_web_app_routes
    end

    scope "/", MyAppWeb do
      pipe_through :browser
      pipe_through :keycloak

      get "/login", AuthorizeController, :login
      post "/logout", AuthorizeController, :logout
      get "/callback", AuthorizeController, :callback
    end
  end
  ```
  """

  defmacro __using__(params) do
    if is_nil(params[:site]), do: raise("site not set")
    if is_nil(params[:realm]), do: raise("realm not set")
    if is_nil(params[:client_id]), do: raise("client_id not set")
    if is_nil(params[:redirect_uri]), do: raise("redirect_uri not set")
    if is_nil(params[:client_secret]), do: raise("client_secret not set")

    quote do
      def refresh_token(refresh_token) do
        PhxKeycloak.UseCases.KeycloakRefreshToken.call(refresh_token, Map.new(unquote(params)))
      end

      def logout(refresh_token) do
        PhxKeycloak.UseCases.KeycloakLogout.call(refresh_token, Map.new(unquote(params)))
      end

      def get_user_claims(refresh_token) do
        PhxKeycloak.UseCases.KeycloakUserClaims.call(refresh_token, Map.new(unquote(params)))
      end

      def get_tokens_by_code(code) do
        PhxKeycloak.UseCases.KeycloakGetTokensByCode.call(code, Map.new(unquote(params)))
      end

      def authorize_url() do
        PhxKeycloak.UseCases.KeycloakAuthorizeUrl.call(Map.new(unquote(params)))
      end

      defmodule Plugs.GetClaimsPlug do
        @moduledoc false
        import Plug.Conn
        require Logger

        def init(options) do
          # initialize options
          options
        end

        def call(conn, _opts) do
          existing_refresh_token = get_session(conn, :refresh_token)

          {access_token, refresh_token} =
            PhxKeycloak.UseCases.KeycloakRefreshToken.call(
              existing_refresh_token,
              Map.new(unquote(params))
            )

          claims =
            PhxKeycloak.UseCases.KeycloakUserClaims.call(access_token, Map.new(unquote(params)))

          case is_nil(claims) || %{} == claims do
            true ->
              Logger.warn("Plugs.GetClaimsPlug: no claims, clearing session")

              clear_session(conn)

            false ->
              conn
              |> put_session(:refresh_token, refresh_token)
              |> assign(:claims, claims)
          end
        end
      end

      defmodule Plugs.RefreshUserTokenPlug do
        @moduledoc false
        import Plug.Conn

        def init(options) do
          # initialize options
          options
        end

        def call(conn, _opts) do
          existing_refresh_token = get_session(conn, :refresh_token)

          {_access_token, refresh_token} =
            PhxKeycloak.UseCases.KeycloakRefreshToken.call(
              existing_refresh_token,
              Map.new(unquote(params))
            )

          conn
          |> put_session(:refresh_token, refresh_token)
        end
      end

      defmodule Plugs.RedirectUnauthorizedUserToLoginPlug do
        @moduledoc """
        Если пользователь не авторизован, то он будет переадресован на страницу авторизации
        """
        def init(redirect_route: redirect_page) do
          # initialize options
          redirect_page
        end

        def call(conn, redirect_page) do
          case conn.assigns[:claims] do
            nil ->
              conn
              |> Phoenix.Controller.redirect(to: redirect_page)
              |> Plug.Conn.halt()

            _some_value ->
              conn
          end
        end
      end
    end
  end
end
