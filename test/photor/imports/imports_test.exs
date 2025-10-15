defmodule ImporterStub do
  def dummy_test_callback(_import, _source_dir, _import_opts, _fun), do: :ok
end

defmodule Photor.ImportsTest do
  use Photor.DataCase

  alias Photor.Imports
  alias Photor.Imports.Events
  alias Photor.Imports.Import
  alias Photor.Imports.ImportRegistry
  alias Photor.Imports.ImportSession
  alias Photor.Imports.ImportSupervisor

  import Photor.Factory

  @test_assets "test/assets/import_source"

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

  describe "import_directory/1" do
    test "creates a new import record" do
      test_callback = fn import, source_dir, import_opts, fun ->
        assert %Import{} = import
        assert i = Repo.get!(Import, import.id)
        assert import.started_at == i.started_at

        assert source_dir == @test_assets
        assert import_opts == []
        assert is_function(fun, 1)

        :ok
      end

      assert {:ok, %Import{}} = Imports.import_directory(@test_assets, test_callback)
    end

    test "starts an import session" do
      assert {:ok, %Import{} = import} =
               Imports.import_directory(@test_assets, &ImporterStub.dummy_test_callback/4)

      state = :sys.get_state({:via, Registry, {ImportRegistry, import.id}})

      # Check that we can get the state of the import session
      assert is_map(state)
      assert state.import_id == import.id
    end
  end

  describe "get_all_imports_info/0" do
    test "works" do
      # this one is quite tricky since this function asks gensersers for their
      # data. Each import starts a genserver to store the current state of the
      # import, and get_all_imports_info/0 fetches their state to make it quick.
      # So the setup needs to fill those genservers with data. To do so, fake
      # events are created and processed manually. That way we hopefully don't
      # have to update the tests each time the shape of the genservers state is
      # changed. However it's a lot of setup for a test.
      [import1, import2] = insert_pair(:import)
      ImportSupervisor.start_import_session(import1)
      ImportSupervisor.start_import_session(import2)
      ImportSession.process_event(import1.id, %Events.NewImport{})
      ImportSession.process_event(import2.id, %Events.NewImport{})

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
                 nb_files: 0,
                 nb_files_to_import: 0,
                 nb_files_skipped: 0,
                 nb_files_imported: 0,
                 current_file_path: nil,
                 bytes_to_import: 0,
                 bytes_imported: 0,
                 last_event_id: 1
               },
               import2.id => %{
                 started_at: import2.started_at,
                 import_id: import2.id,
                 import_status: :started,
                 nb_files: 2,
                 nb_files_to_import: 0,
                 nb_files_skipped: 0,
                 nb_files_imported: 0,
                 current_file_path: nil,
                 bytes_to_import: 0,
                 bytes_imported: 0,
                 last_event_id: 2
               }
             }
    end
  end

  describe "subscribe_to_import_sessions/0" do
    test "subscribes the current process to a phoenix pubsub" do
      assert :ok = Imports.subscribe_to_import_sessions()

      Phoenix.PubSub.broadcast(
        Imports.pubsub_name(),
        Imports.pubsub_topic(),
        :some_payload
      )

      assert_receive :some_payload
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
