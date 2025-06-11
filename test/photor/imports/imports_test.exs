defmodule Photor.ImportsTest do
  use Photor.DataCase

  alias Photor.Imports
  alias Photor.Imports.ImportSession
  alias Photor.Imports.Events
  alias Photor.Imports.Import
  alias Photor.Imports.ImportRegistry

  import Photor.Factory

  setup do
    on_exit(fn ->
      # Tests are using the application's ImportSupervisor and so are stateful.
      # All its children processes are terminated before each test:
      DynamicSupervisor.which_children(Photor.Imports.ImportSupervisor)
      |> Enum.each(fn {_id, pid, _type, _module} ->
        :ok = DynamicSupervisor.terminate_child(Photor.Imports.ImportSupervisor, pid)
      end)
    end)
  end

  describe "start_import/1" do
    test "creates a new import record" do
      assert {:ok, %Import{} = i} = Imports.start_import("/test/source")

      # Check that an import record was created
      import = Repo.get(Import, i.id)
      assert import != nil
      assert import.started_at == i.started_at
    end

    test "starts an import session" do
      assert {:ok, %Import{} = import} = Imports.start_import("/test/source")

      state = :sys.get_state({:via, Registry, {ImportRegistry, import.id}})

      # Check that we can get the state of the import session
      assert is_map(state)
      assert state.import_id == import.id
    end
  end

  describe "get_all_imports_info/0" do
    test "works" do
      assert {:ok, %Import{} = import1} = Imports.start_import("/test/source")
      assert {:ok, %Import{} = import2} = Imports.start_import("/test/source")

      files = [
        %Photor.Files.File{
          path: "/test/dir/file1.jpg",
          type: %{medium: :photo, type: :compressed, extension: "jpg"},
          bytesize: 1000,
          access: :read_write
        },
        %Photor.Files.File{
          path: "/test/dir/file2.jpg",
          type: %{medium: :photo, type: :compressed, extension: "jpg"},
          bytesize: 2000,
          access: :read_write
        }
      ]

      ImportSession.process_event(import2.id, %Events.FilesFound{
        import_id: import2.id,
        files: files
      })

      assert Imports.get_all_imports_info() == %{
               import1.id => %{
                 started_at: import1.started_at,
                 import_id: import1.id,
                 import_status: :started,
                 total_number_of_files: 0,
                 files_skipped: 0,
                 files_imported: 0,
                 current_file_path: nil,
                 total_bytes: 0,
                 skipped_bytes: 0,
                 imported_bytes: 0,
                 last_event_id: 1
               },
               import2.id => %{
                 started_at: import2.started_at,
                 import_id: import2.id,
                 import_status: :started,
                 total_number_of_files: 2,
                 files_skipped: 0,
                 files_imported: 0,
                 current_file_path: nil,
                 total_bytes: 3000,
                 skipped_bytes: 0,
                 imported_bytes: 0,
                 last_event_id: 2
               }
             }
    end
  end

  describe "subscribe_to_import_sessions/0" do
    test "subscribes the current process to a phoenix pubsub" do
      assert :ok = Imports.subscribe_to_import_sessions()
      assert {:ok, %Import{} = import1} = Imports.start_import("/test/source")

      import_id = import1.id
      assert_receive {:import_update, ^import_id, payload}

      assert payload == %{
               started_at: import1.started_at,
               import_id: import1.id,
               import_status: :started,
               total_number_of_files: 0,
               files_skipped: 0,
               files_imported: 0,
               current_file_path: nil,
               total_bytes: 0,
               skipped_bytes: 0,
               imported_bytes: 0,
               last_event_id: 1
             }
    end
  end

  describe "get_most_recent_import/0" do
    test "returns the most recent import" do
      [_import1, import2] =
        Enum.map(1..2, fn _ ->
          i = insert(:import)
          # Wait a moment to ensure different timestamps
          :timer.sleep(2)
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
