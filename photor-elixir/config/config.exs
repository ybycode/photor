# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :photor,
  ecto_repos: [Photor.Repo],
  generators: [timestamp_type: :utc_datetime]

config :photor, Photor.FileExtensions,
  # Those definitions are required at compile time:
  data: %{
    {:photo, :raw} => [
      "3fr",
      "arw",
      "cr2",
      "cr3",
      "dng",
      "fff",
      "nef",
      "nrw",
      "orf",
      "pef",
      "raf",
      "raw",
      "rw2",
      "sr2",
      "srf",
      "x3f"
    ],
    {:photo, :compressed} => ["jpg", "jpeg", "heic", "heif"],
    # mxf can also be used for raw video (sony). This software will detect them
    # as compressed.
    {:video, :compressed} => ["avi", "mov", "mp4", "mxf"],
    {:video, :raw} => ["crm"]
  }

# Configures the endpoint
config :photor, PhotorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PhotorWeb.ErrorHTML, json: PhotorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Photor.PubSub,
  live_view: [signing_salt: "EDZNykio"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  photor: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  photor: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
