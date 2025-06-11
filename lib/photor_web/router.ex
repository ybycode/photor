defmodule PhotorWeb.Router do
  use PhotorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhotorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PhotorWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/albums", AlbumsLive.Index
    live "/albums/:date", AlbumsLive.Show
    live "/imports", ImportLive.Index
    # get "/:date", PageController, :album
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhotorWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:photor, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhotorWeb.Telemetry
    end
  end
end
