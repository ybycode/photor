defmodule Photor.ImportsTest do
  use Photor.DataCase

  alias Photor.Imports
  alias Photor.Imports.Import

  import Photor.Factory

  describe "start_import/1" do
    test "creates a new import record" do
      {:ok, %Import{} = i} = Imports.start_import("/test/source")

      # Check that an import record was created
      import = Repo.get(Import, i.id)
      assert import != nil
      assert import.started_at == i.started_at
    end
  end

  describe "get_most_recent_import/0" do
    test "returns the most recent import" do
      [_import1, import2] =
        Enum.map(1..2, fn _ ->
          i = insert(:import)
          # Wait a moment to ensure different timestamps
          :timer.sleep(10)
          i
        end)

      # Get the most recent import
      most_recent = Imports.get_most_recent_import()

      # It should be the second one
      assert most_recent.id == import2.id
    end

    test "returns nil when no imports exist" do
      assert Imports.get_most_recent_import() == nil
    end
  end
end
