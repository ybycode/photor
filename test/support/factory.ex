defmodule Photor.Factory do
  # with Ecto

  use ExMachina.Ecto, repo: Photor.Repo

  alias Photor.Imports.Import

  def import_factory do
    %Import{}
  end
end
