defmodule Photor.Imports.ImportSessionTest do
  use Photor.DataCase

  alias Photor.Imports.Events
  alias Photor.Imports.ImportSession
  alias Photor.Imports.ImportSessionState
  alias Photor.TestHelpers

  import Photor.Factory

  setup do
    import = insert(:import)

    pid =
      start_link_supervised!(%{
        id: :test_import_session,
        start: {ImportSession, :start_link, [import]}
      })

    {:ok, %{import: import, import_session_pid: pid}}
  end

  defp setup_fetch_import_events(%{import: import}) do
    events = TestHelpers.expected_events(import)

    {:ok, events: events}
  end

  describe "get_import_info/1" do
    test "returns information about the import tracked by the genserver", %{
      import: import
    } do
      assert ImportSession.get_import_info(import.id) ==
               {:ok,
                %{
                  started_at: import.started_at,
                  import_id: import.id,
                  import_status: :starting,
                  nb_files: 0,
                  nb_files_skipped: 0,
                  nb_files_to_import: 0,
                  bytes_to_import: 0,
                  nb_files_imported: 0,
                  bytes_imported: 0,
                  current_file_path: nil,
                  last_event_id: 0
                }}
    end
  end

  @files %{
    "test/assets/import_source/photo1.jpg" => %Photor.Imports.FileImport{
      access: :read_write,
      status: :todo,
      type: %{type: :compressed, extension: "jpg", medium: :photo},
      path: "test/assets/import_source/photo1.jpg",
      bytesize: 15
    },
    "test/assets/import_source/sub1/photo2.jpg" => %Photor.Imports.FileImport{
      access: :read_write,
      status: :todo,
      type: %{type: :compressed, extension: "jpg", medium: :photo},
      path: "test/assets/import_source/sub1/photo2.jpg",
      bytesize: 15
    },
    "test/assets/import_source/sub1/sub2/photo3.jpg" => %Photor.Imports.FileImport{
      access: :read_write,
      status: :todo,
      type: %{type: :compressed, extension: "jpg", medium: :photo},
      path: "test/assets/import_source/sub1/sub2/photo3.jpg",
      bytesize: 15
    }
  }

  describe "import session" do
    # TODO: add setup for skipped file
    setup :setup_fetch_import_events

    test "reacts to all events of an import", %{
      import: import,
      import_session_pid: import_session_pid,
      events: events
    } do
      assert :sys.get_state(import_session_pid) == %ImportSessionState{
               started_at: import.started_at,
               import_id: import.id,
               import_status: :starting,
               current_file_path: nil,
               files: %{},
               nb_files: 0,
               nb_files_skipped: 0,
               nb_files_to_import: 0,
               nb_files_imported: 0,
               bytes_to_import: 0,
               bytes_imported: 0,
               last_event_id: 0
             }

      Enum.zip(events, [
        {Events.NewImport,
         fn s ->
           assert s == %ImportSessionState{
                    started_at: import.started_at,
                    import_id: import.id,
                    import_status: :started,
                    current_file_path: nil,
                    files: %{},
                    nb_files: 0,
                    nb_files_imported: 0,
                    nb_files_skipped: 0,
                    nb_files_to_import: 0,
                    bytes_to_import: 0,
                    bytes_imported: 0,
                    last_event_id: 1
                  }
         end},
        {Events.FilesFound,
         fn s ->
           assert s.files == @files
           assert s.last_event_id == 2
         end},
        {Events.ScanStarted,
         fn s ->
           assert %ImportSessionState{
                    import_status: :scanning,
                    current_file_path: nil,
                    files: @files,
                    nb_files: 3,
                    nb_files_skipped: 0,
                    nb_files_to_import: 0,
                    nb_files_imported: 0,
                    bytes_imported: 0,
                    bytes_to_import: 0,
                    last_event_id: 3
                  } = s
         end},
        {Events.FileAlreadyInRepoFound, & &1},
        {Events.FileNotYetInRepoFound, & &1},
        {Events.FileNotYetInRepoFound,
         fn s ->
           # assert Map.values(s.files) |> Enum.map(& &1.status) |> Enum.all?(&(&1 == :to_import))
           assert s.nb_files == 3
           assert s.nb_files_skipped == 1
           assert s.nb_files_to_import == 2
           assert s.nb_files_imported == 0
           assert s.bytes_to_import == 30
           assert s.bytes_imported == 0
           assert s.last_event_id == 6
         end},
        {Events.ImportStarted,
         fn s ->
           assert s.nb_files == 3
           assert s.nb_files_skipped == 1
           assert s.nb_files_to_import == 2
           assert s.import_status == :files_import
           assert s.last_event_id == 7
         end},
        {Events.FileImporting,
         fn s ->
           assert s.nb_files == 3
           assert s.import_status == :files_import
           assert s.nb_files_skipped == 1
           assert s.nb_files_to_import == 2
           assert s.nb_files_imported == 0
           assert s.bytes_to_import == 30
           assert s.bytes_imported == 0
           assert s.last_event_id == 8
           assert not is_nil(s.current_file_path)
         end},
        {Events.FileImported,
         fn s ->
           assert s.import_status == :files_import
           assert s.nb_files == 3
           assert s.nb_files_skipped == 1
           assert s.nb_files_to_import == 2
           assert s.nb_files_imported == 1
           assert s.bytes_to_import == 30
           assert s.bytes_imported == 15
           assert s.last_event_id == 9
           assert not is_nil(s.current_file_path)
         end},
        {Events.FileImporting, & &1},
        {Events.FileImported, & &1},
        {Events.ImportFinished,
         fn s ->
           assert s.import_status == :finished
           assert s.nb_files_skipped == 1
           assert s.nb_files_to_import == 2
           assert s.nb_files_imported == 2
           assert s.bytes_to_import == 30
           assert s.bytes_imported == 30
           assert s.last_event_id == 12
           assert is_nil(s.current_file_path)
         end}
      ])
      |> Enum.each(fn {event, {expected_event, test_fn}} ->
        assert event.__struct__ == expected_event
        ImportSession.process_event(import.id, event)

        assert :sys.get_state(import_session_pid) |> test_fn.()
      end)
    end
  end
end
