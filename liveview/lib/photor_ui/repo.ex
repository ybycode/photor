defmodule PhotorUi.Repo do
  use Ecto.Repo,
    otp_app: :photor_ui,
    adapter: Ecto.Adapters.SQLite3
end
