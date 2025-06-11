defmodule Photor.Imports.ImportSessionTest do
  use Photor.DataCase

  alias Photor.Imports.Events
  alias Photor.Imports.ImportSession

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
                  total_number_of_files: 0,
                  files_skipped: 0,
                  files_imported: 0,
                  current_file_path: nil,
                  total_bytes: 0,
                  skipped_bytes: 0,
                  imported_bytes: 0,
                  last_event_id: 0
                }}
    end
  end

  describe "import session" do
    test "initializes with correct state", %{
      import: import,
      import_session_pid: import_session_pid
    } do
      state = :sys.get_state(import_session_pid)

      assert state.import_id == import.id
      assert state.import_status == :starting
      assert state.files == %{}
      assert state.current_file_path == nil
      assert state.total_bytes == 0
      assert state.skipped_bytes == 0
      assert state.imported_bytes == 0
      assert state.last_event_id == 0
    end

    test "processes import started event", %{
      import: import,
      import_session_pid: import_session_pid
    } do
      event = %Events.ImportStarted{
        import_id: import.id,
        started_at: import.started_at,
        source_dir: "/test/dir"
      }

      ImportSession.process_event(import.id, event)

      state = :sys.get_state(import_session_pid)
      assert state.import_status == :started
      assert state.last_event_id == 1
    end

    test "processes files found event", %{import: import, import_session_pid: import_session_pid} do
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

      event1 = %Events.FilesFound{
        import_id: import.id,
        files: files
      }

      ImportSession.process_event(import.id, event1)

      state = :sys.get_state(import_session_pid)
      assert state.import_status == :scanning
      assert state.total_number_of_files == 2

      assert state.files == %{
               "/test/dir/file1.jpg" => %Photor.Imports.FileImport{
                 access: :read_write,
                 status: :todo,
                 type: %{type: :compressed, extension: "jpg", medium: :photo},
                 path: "/test/dir/file1.jpg",
                 bytesize: 1000
               },
               "/test/dir/file2.jpg" => %Photor.Imports.FileImport{
                 access: :read_write,
                 status: :todo,
                 type: %{type: :compressed, extension: "jpg", medium: :photo},
                 path: "/test/dir/file2.jpg",
                 bytesize: 2000
               }
             }

      assert state.total_bytes == 3000
      assert state.skipped_bytes == 0
      assert state.last_event_id == 1

      event2 = %Events.FilesFound{
        import_id: import.id,
        files: [
          %Photor.Files.File{
            path: "/test/dir/file3.jpg",
            type: %{medium: :photo, type: :compressed, extension: "jpg"},
            bytesize: 4000,
            access: :read_write
          }
        ]
      }

      ImportSession.process_event(import.id, event2)

      state = :sys.get_state(import_session_pid)
      assert state.total_bytes == 7000
      assert state.last_event_id == 2
      assert state.total_number_of_files == 3
    end

    test "processes file skipped event", %{import: import, import_session_pid: import_session_pid} do
      # First add some files
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
        },
        %Photor.Files.File{
          path: "/test/dir/file3.jpg",
          type: %{medium: :photo, type: :compressed, extension: "jpg"},
          bytesize: 3000,
          access: :read_write
        }
      ]

      ImportSession.process_event(import.id, %Events.FilesFound{
        import_id: import.id,
        files: files
      })

      # Now skip two files
      ImportSession.process_event(import.id, %Events.FileSkipped{
        import_id: import.id,
        path: "/test/dir/file1.jpg"
      })

      ImportSession.process_event(import.id, %Events.FileSkipped{
        import_id: import.id,
        path: "/test/dir/file3.jpg"
      })

      state = :sys.get_state(import_session_pid)

      assert [skipped1, _skipped2] =
               Map.values(state.files) |> Enum.filter(&(&1.status == :skipped))

      assert skipped1.path == "/test/dir/file1.jpg"
      assert state.files_skipped == 2
      assert state.skipped_bytes == 4000
      # there's been 3 events:
      assert state.last_event_id == 3
    end

    test "processes file importing and imported events", %{
      import: import,
      import_session_pid: import_session_pid
    } do
      # First add some files
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

      ImportSession.process_event(import.id, %Events.FilesFound{
        import_id: import.id,
        files: files
      })

      # Start importing a file
      ImportSession.process_event(import.id, %Events.FileImporting{
        import_id: import.id,
        path: "/test/dir/file1.jpg"
      })

      state = :sys.get_state(import_session_pid)
      assert state.import_status == :importing
      assert state.current_file_path == "/test/dir/file1.jpg"

      # Complete the import
      ImportSession.process_event(import.id, %Events.FileImported{
        import_id: import.id,
        path: "/test/dir/file1.jpg"
      })

      state = :sys.get_state(import_session_pid)
      assert state.current_file_path == nil
      assert [imported] = Map.values(state.files) |> Enum.filter(&(&1.status == :imported))
      assert imported.path == "/test/dir/file1.jpg"
      assert state.imported_bytes == 1000
      assert state.last_event_id == 3
    end

    test "processes import finished event", %{
      import: import,
      import_session_pid: import_session_pid
    } do
      assert ImportSession.get_import_info(import.id) ==
               {:ok,
                %{
                  started_at: import.started_at,
                  import_id: import.id,
                  import_status: :starting,
                  total_number_of_files: 0,
                  files_skipped: 0,
                  files_imported: 0,
                  current_file_path: nil,
                  total_bytes: 0,
                  skipped_bytes: 0,
                  imported_bytes: 0,
                  last_event_id: 0
                }}

      # First add some files and mark them as imported
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

      ImportSession.process_event(import.id, %Events.FilesFound{
        import_id: import.id,
        files: files
      })

      assert ImportSession.get_import_info(import.id) ==
               {:ok,
                %{
                  started_at: import.started_at,
                  import_id: import.id,
                  import_status: :scanning,
                  total_number_of_files: 2,
                  files_skipped: 0,
                  files_imported: 0,
                  current_file_path: nil,
                  total_bytes: 3000,
                  skipped_bytes: 0,
                  imported_bytes: 0,
                  last_event_id: 1
                }}

      # Import both files
      Enum.each(files, fn file ->
        ImportSession.process_event(import.id, %Events.FileImporting{
          import_id: import.id,
          path: file.path
        })

        ImportSession.process_event(import.id, %Events.FileImported{
          import_id: import.id,
          path: file.path
        })
      end)

      assert ImportSession.get_import_info(import.id) ==
               {:ok,
                %{
                  started_at: import.started_at,
                  import_id: import.id,
                  import_status: :importing,
                  total_number_of_files: 2,
                  files_skipped: 0,
                  files_imported: 2,
                  current_file_path: nil,
                  total_bytes: 3000,
                  skipped_bytes: 0,
                  imported_bytes: 3000,
                  last_event_id: 5
                }}

      # Finish the import
      ImportSession.process_event(import.id, %Events.ImportFinished{import_id: import.id})

      assert ImportSession.get_import_info(import.id) ==
               {:ok,
                %{
                  started_at: import.started_at,
                  import_id: import.id,
                  import_status: :finished,
                  total_number_of_files: 2,
                  files_skipped: 0,
                  files_imported: 2,
                  current_file_path: nil,
                  total_bytes: 3000,
                  skipped_bytes: 0,
                  imported_bytes: 3000,
                  last_event_id: 6
                }}

      state = :sys.get_state(import_session_pid)
      assert [_f1, _f2] = Map.values(state.files) |> Enum.filter(&(&1.status == :imported))
    end
  end
end
