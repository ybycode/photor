defmodule Photor.Imports.ImportSessionTest do
  use Photor.DataCase
  import Mox

  alias Photor.Imports.Events
  alias Photor.Imports.Importer
  alias Photor.Imports.ImportSession
  alias Photor.Imports.ImportSessionState
  alias Photor.Metadata.MockExiftool

  import Photor.Factory

  setup :verify_on_exit!

  @photor_dir Application.compile_env!(:photor, :photor_dir)
  @source_dir "test/tmp/"

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
    cleanup_directories()
    events = import_and_record_events(import)

    {:ok, events: events}
  end

  defp cleanup_directories() do
    # Create temp directories for tests
    File.mkdir_p!(@source_dir)

    on_exit(fn ->
      File.rm_rf!(@source_dir)

      [
        "1970-01-01",
        "2023-06-15"
      ]
      |> Enum.each(fn date ->
        Path.join(@photor_dir, date)
        |> File.rm_rf!()
      end)
    end)
  end

  defp import_and_record_events(import) do
    # Create test files
    file1 = Path.join(@source_dir, "photo1.jpg")
    file2 = Path.join(@source_dir, "photo2.jpg")
    File.write!(file1, "test content 1")
    File.write!(file2, "test content 2")

    # Create a subdirectory with a file
    subdir = Path.join(@source_dir, "subdir")
    File.mkdir_p!(subdir)
    file3 = Path.join(subdir, "photo3.jpg")
    File.write!(file3, "test content 3")

    # Mock the metadata read for each file
    MockExiftool
    |> expect(:read_as_json, 3, fn path ->
      filename = Path.basename(path)

      {:ok,
       %{
         "FileName" => filename,
         "CreateDate" => "2023-06-15 10:30:00",
         "MIMEType" => "image/jpeg"
       }}
    end)

    # run the import and collect all events, to replay them manually to our genserver:
    test_pid = self()

    # run an import to receive all events:
    assert :ok =
             Importer.import_directory(import, @source_dir, [], fn event ->
               send(test_pid, event)
             end)

    # read how many events were received:
    nb_events_received = Process.info(self())[:message_queue_len]

    # fetch and return all messages (events):

    Enum.map(1..nb_events_received, fn _ ->
      receive do
        msg -> msg
      end
    end)
  end

  describe "get_import_info/1" do
    test "returns information about the import tracked by the genserver", %{
      import: import
    } do
      assert ImportSession.get_import_info(import.id) ==
               {:ok,
                %{
                  started_at: import.started_at,
                  import_id: 1,
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
    "test/tmp/photo1.jpg" => %Photor.Imports.FileImport{
      access: :read_write,
      status: :todo,
      type: %{type: :compressed, extension: "jpg", medium: :photo},
      path: "test/tmp/photo1.jpg",
      bytesize: 14
    },
    "test/tmp/photo2.jpg" => %Photor.Imports.FileImport{
      access: :read_write,
      status: :todo,
      type: %{type: :compressed, extension: "jpg", medium: :photo},
      path: "test/tmp/photo2.jpg",
      bytesize: 14
    },
    "test/tmp/subdir/photo3.jpg" => %Photor.Imports.FileImport{
      access: :read_write,
      status: :todo,
      type: %{type: :compressed, extension: "jpg", medium: :photo},
      path: "test/tmp/subdir/photo3.jpg",
      bytesize: 14
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
        {Events.FileNotYetInRepoFound, & &1},
        {Events.FileNotYetInRepoFound, & &1},
        {Events.FileNotYetInRepoFound,
         fn s ->
           assert Map.values(s.files) |> Enum.map(& &1.status) |> Enum.all?(&(&1 == :to_import))
           assert s.nb_files_skipped == 0
           assert s.nb_files_to_import == 3
           assert s.nb_files_imported == 0
           assert s.bytes_to_import == 42
           assert s.bytes_imported == 0
           assert s.last_event_id == 6
         end},
        {Events.ImportStarted,
         fn s ->
           assert s.import_status == :files_import
           assert s.last_event_id == 7
         end},
        {Events.FileImporting,
         fn s ->
           assert s.import_status == :files_import
           assert s.nb_files_skipped == 0
           assert s.nb_files_to_import == 3
           assert s.nb_files_imported == 0
           assert s.bytes_to_import == 42
           assert s.bytes_imported == 0
           assert s.last_event_id == 8
           assert not is_nil(s.current_file_path)
         end},
        {Events.FileImported,
         fn s ->
           assert s.import_status == :files_import
           assert s.nb_files_skipped == 0
           assert s.nb_files_to_import == 3
           assert s.nb_files_imported == 1
           assert s.bytes_to_import == 42
           assert s.bytes_imported == 14
           assert s.last_event_id == 9
           assert not is_nil(s.current_file_path)
         end},
        {Events.FileImporting, & &1},
        {Events.FileImported, & &1},
        {Events.FileImporting, & &1},
        {Events.FileImported, & &1},
        {Events.ImportFinished,
         fn s ->
           assert s.import_status == :finished
           assert s.nb_files_skipped == 0
           assert s.nb_files_to_import == 3
           assert s.nb_files_imported == 3
           assert s.bytes_to_import == 42
           assert s.bytes_imported == 42
           assert s.last_event_id == 14
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
