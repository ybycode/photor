defmodule Photor.Repo do
  use Ecto.Repo,
    otp_app: :photor,
    adapter: Ecto.Adapters.SQLite3
end
