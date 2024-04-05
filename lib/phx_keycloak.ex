defmodule PhxKeycloak do
  @moduledoc """
  # Settings

  ## Main module

  First of all, we have to define main module, which will be responsible for auth by Keycloak

  Required params:

    * realm - realm ID

    * site - endpoint Keycloak

    * client_id - Keycloak client identity

    * client_secret - Keycloak client secret token

    * redirect_uri - callback for your app


  Optional params:

    * expected_group - Role (Group), which have access to application

  ```elixir
    defmodule MyAppWeb.Keycloak do
      use PhxKeycloak, realm: "cronos",
        site: "http://localhost:8080",
        client_id: "cronos_check_app",
        client_secret: "7c9fb08e-2d11-4921-bc02-cc21c92b6139",
        redirect_uri: "http://localhost:4000/callback",
        expected_group: "app_admin"
    end
  ```

  ## Plugs

  After this we have next Plug's:

    * MyAppWeb.Keycloak.Plugs.RefreshUserTokenPlug - token update and refresh

    * MyAppWeb.Keycloak.Plugs.GetClaimsPlug - get claims about user

    * MyAppWeb.Keycloak.Plugs.RedirectUnauthorizedUserToLoginPlug, redirect_route: "/login" - redirect to login page

  ## Controller

  Define controller, for login and logout user:

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

  In MyAppWeb.Router add next pipeline's:

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

  Now, our router looks like this:

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
      plug Keycloak.Plugs.RefreshUserTokenPlug, Keycloak
      plug Keycloak.Plugs.GetClaimsPlug, Keycloak
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

      def expected_group() do
        unquote(params[:expected_group])
      end

      defmodule Plugs.GetClaimsPlug do
        @moduledoc false
        import Plug.Conn
        import Phoenix.Controller, only: [put_flash: 3]
        require Logger

        def init(keycloak_module) do
          # initialize options
          keycloak_module
        end

        def call(conn, keycloak_module) do
          existing_refresh_token = get_session(conn, :refresh_token)

          {access_token, refresh_token} = keycloak_module.refresh_token(existing_refresh_token)

          claims = keycloak_module.get_user_claims(access_token)
          groups = Access.get(claims, "groups")

          if is_nil(groups) do
            Logger.warning(
              "Plugs.GetClaimsPlug: In Client settings enable Mappers -> Add builtin -> groups"
            )
          end

          groups = groups || []
          expected_group = keycloak_module.expected_group()

          cond do
            is_nil(claims) ->
              Logger.warning("Plugs.GetClaimsPlug: nil claims, clearing session")
              clear_session(conn)

            %{} == claims && Map.keys(claims) == [] ->
              Logger.warning("Plugs.GetClaimsPlug: empty claims, clearing session")
              clear_session(conn)

            expected_group != nil and expected_group not in groups ->
              Logger.warning(
                "Plugs.GetClaimsPlug: no expected_group in claims' groups, clearing session"
              )

              conn
              |> clear_session()
              |> put_flash(:error, "PhxKeycloak: User should have role ##{expected_group}")

            true ->
              conn
              |> put_session(:refresh_token, refresh_token)
              |> assign(:claims, claims)
          end
        end
      end

      defmodule Plugs.RefreshUserTokenPlug do
        @moduledoc false
        import Plug.Conn

        def init(keycloak_module) do
          # initialize options
          keycloak_module
        end

        def call(conn, keycloak_module) do
          existing_refresh_token = get_session(conn, :refresh_token)

          {_access_token, refresh_token} = keycloak_module.refresh_token(existing_refresh_token)

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
