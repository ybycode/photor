defmodule Photor.Imports.ImporterTest do
  use Photor.DataCase
  import Mox

  alias Photor.Imports.Importer
  alias Photor.TestHelpers

  import Photor.Factory

  setup :verify_on_exit!

  # @photor_dir Application.compile_env!(:photor, :photor_dir)
  @source_dir "test/assets/import_source"

  describe "generate_filename/2" do
    test "prefixes original filename with hash" do
      original_path = "path/to/IMG_1234.JPG"
      hash = "abcdef1234567890"

      new_name = Importer.generate_filename(original_path, hash)
      assert new_name == "abcdef1234567890_IMG_1234.JPG"
    end
  end

  describe "import_directory/3" do
    test "imports multiple files from a directory" do
      import = insert(:import)

      # this also sets up the mock for exiftool
      TestHelpers.prepare_test_import(import)

      test_pid = self()

      assert :ok =
               Importer.import_directory(import, @source_dir, [], fn event ->
                 send(test_pid, event)
               end)

      expected_events = TestHelpers.expected_events(import)

      received_events = drain_mailbox()

      assert expected_events == received_events
    end

    defp drain_mailbox(acc \\ []) do
      receive do
        msg ->
          drain_mailbox([msg | acc])
      after
        0 ->
          Enum.reverse(acc)
      end
    end

    test "handles directory not found error" do
      # Try to import from a non-existent directory
      import = insert(:import)
      result = Importer.import_directory(import, "/nonexistent/dir")

      # Verify it returns an error
      assert {:error, "Not a directory: /nonexistent/dir"} = result
    end
  end
end
