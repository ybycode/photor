import Config

# Configure your database
config :photor, Photor.Repo,
  # in tests the db file is set in another directory than where the
  # photos are stored. This allows tests to remove files on disk without
  # deleting the db, easily. The db is cleaned up by test transctions
  # anyway.
  database: Path.expand("../test/photos_repo_db/photor.sqlite", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :photor, PhotorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "wUkt49eaqyAuan8JqpJNEaOKSCxMW3Ejn6FbuF3hgzb4+xCpJ1mqjwVTDt9ssVpI",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :photor,
  photor_dir: "test/photos_repo",
  partial_hash_nb_bytes: Integer.to_string(512 * 1024)

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure the Exiftool mock for testing
config :photor, :exiftool_module, Photor.Metadata.MockExiftool
