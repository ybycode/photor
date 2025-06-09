defmodule Photor.Imports.ImportSessionTest do
  use Photor.DataCase

  alias Photor.Imports.Events
  alias Photor.Imports.ImportSession
  alias Photor.Imports.ImportSupervisor

  import Photor.Factory

  describe "import session" do
    setup do
      import = insert(:import)

      # Make sure any previous test's process is stopped
      ImportSupervisor.stop_import_session(import.id)

      {:ok, _pid} = ImportSupervisor.start_import_session(import)

      {:ok, %{import: import}}
    end

    test "initializes with correct state", %{import: import} do
      state = ImportSession.get_state(import.id)

      assert state.import.id == import.id
      assert state.import_status == :starting
      assert state.files == %{}
      assert state.current_file_path == nil
      assert state.total_bytes_to_import == 0
      assert state.imported_bytes == 0
    end

    test "processes import started event", %{import: import} do
      event = %Events.ImportStarted{
        import_id: import.id,
        started_at: import.started_at,
        source_dir: "/test/dir"
      }

      ImportSession.process_event(import.id, event)

      # Give the process a moment to process the event
      # :timer.sleep(50)

      state = ImportSession.get_state(import.id)
      assert state.import_status == :started
    end

    test "processes files found event", %{import: import} do
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

      event = %Events.FilesFound{
        import_id: import.id,
        files: files
      }

      ImportSession.process_event(import.id, event)

      # Give the process a moment to process the event
      # :timer.sleep(50)

      state = ImportSession.get_state(import.id)
      assert state.import_status == :scanning

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

      assert state.total_bytes_to_import == 3000
    end

    test "processes file skipped event", %{import: import} do
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

      # Now skip a file
      ImportSession.process_event(import.id, %Events.FileSkipped{
        import_id: import.id,
        path: "/test/dir/file1.jpg"
      })

      # Give the process a moment to process the events
      # :timer.sleep(50)

      state = ImportSession.get_state(import.id)
      assert [skipped] = Map.values(state.files) |> Enum.filter(&(&1.status == :skipped))
      assert skipped.path == "/test/dir/file1.jpg"
    end

    test "processes file importing and imported events", %{import: import} do
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

      # Give the process a moment to process the events
      # :timer.sleep(50)

      state = ImportSession.get_state(import.id)
      assert state.import_status == :importing
      assert state.current_file_path == "/test/dir/file1.jpg"

      # Complete the import
      ImportSession.process_event(import.id, %Events.FileImported{
        import_id: import.id,
        path: "/test/dir/file1.jpg"
      })

      state = ImportSession.get_state(import.id)
      assert state.current_file_path == nil
      assert [imported] = Map.values(state.files) |> Enum.filter(&(&1.status == :imported))
      assert imported.path == "/test/dir/file1.jpg"
      assert state.imported_bytes == 1000
    end

    test "processes import finished event", %{import: import} do
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

      # Finish the import
      ImportSession.process_event(import.id, %Events.ImportFinished{
        import_id: import.id,
        total_files: 2,
        skipped_count: 0,
        imported_count: 2,
        imported_bytes: 3000
      })

      # Give the process a moment to process the events
      # :timer.sleep(50)

      state = ImportSession.get_state(import.id)
      assert state.import_status == :finished
      assert [_f1, _f2] = Map.values(state.files) |> Enum.filter(&(&1.status == :imported))
      assert state.imported_bytes == 3000
    end
  end
end
