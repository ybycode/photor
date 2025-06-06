defmodule Photor.Imports.ImportTrackerTest do
  use ExUnit.Case, async: false

  alias Photor.Files.File, as: File_
  alias Photor.Imports.FileImport
  alias Photor.Imports.Events.FileImported
  # alias Photor.Imports.Events.FileImporting
  alias Photor.Imports.Events.FileSkipped
  alias Photor.Imports.Events.FilesFound
  # alias Photor.Imports.Events.ImportError
  alias Photor.Imports.Events.ImportFinished
  alias Photor.Imports.Events.ImportStarted
  alias Photor.Imports.ImportTracker

  @test_tracker :test_tracker

  setup do
    # Start the ImportTracker for testing
    start_link_supervised!(%{
      id: :plop,
      start: {ImportTracker, :start_link, [[name: @test_tracker]]}
    })

    :ok
  end

  describe "init" do
    test "initial state is empty" do
      state = ImportTracker.get_state(@test_tracker)
      assert state.files_by_path == %{}
      assert state.last_event_id == 0
    end
  end

  describe "Events are handled ok by the GenServer:" do
    test "%ImportStarted{}" do
      now = DateTime.utc_now()

      assert :ok =
               GenServer.call(@test_tracker, %ImportStarted{
                 import_id: 22,
                 started_at: now,
                 source_dir: "/some/dir"
               })

      state = ImportTracker.get_state(@test_tracker)
      assert state.files_by_path == %{}
      assert state.last_event_id == 1
    end

    test "%FilesFound{}" do
      assert :ok =
               GenServer.call(@test_tracker, %FilesFound{
                 files: [
                   %File_{
                     path: "/some/dir/1.JPG",
                     type: {:photo, :compressed},
                     bytesize: 100
                   },
                   %File_{path: "/some/dir/2.RAF", type: {:photo, :raw}, bytesize: 200}
                 ]
               })

      # some more, in a second wave:
      assert :ok =
               GenServer.call(@test_tracker, %FilesFound{
                 files: [
                   %File_{
                     path: "/some/dir/3.MP4",
                     type: {:video, :compressed},
                     bytesize: 300
                   },
                   %File_{path: "/some/dir/4.CRM", type: {:video, :raw}, bytesize: 400}
                 ]
               })

      state = ImportTracker.get_state(@test_tracker)

      assert state.files_by_path == %{
               "/some/dir/1.JPG" => %FileImport{
                 path: "/some/dir/1.JPG",
                 type: {:photo, :compressed},
                 status: :todo,
                 bytesize: 100
               },
               "/some/dir/2.RAF" => %FileImport{
                 path: "/some/dir/2.RAF",
                 type: {:photo, :raw},
                 status: :todo,
                 bytesize: 200
               },
               "/some/dir/3.MP4" => %FileImport{
                 path: "/some/dir/3.MP4",
                 type: {:video, :compressed},
                 status: :todo,
                 bytesize: 300
               },
               "/some/dir/4.CRM" => %FileImport{
                 path: "/some/dir/4.CRM",
                 type: {:video, :raw},
                 status: :todo,
                 bytesize: 400
               }
             }

      assert state.last_event_id == 2
    end

    test "%FileSkipped{}" do
      # the state is populated:
      assert :ok =
               GenServer.call(@test_tracker, %FilesFound{
                 files: [
                   %File_{
                     path: "/some/dir/3.MP4",
                     type: {:video, :compressed},
                     bytesize: 300
                   },
                   %File_{path: "/some/dir/4.CRM", type: {:video, :raw}, bytesize: 400}
                 ]
               })

      # the skip event:
      assert :ok =
               GenServer.call(@test_tracker, %FileSkipped{
                 path: "/some/dir/3.MP4"
               })

      state = ImportTracker.get_state(@test_tracker)

      assert state.files_by_path == %{
               "/some/dir/3.MP4" => %FileImport{
                 path: "/some/dir/3.MP4",
                 type: {:video, :compressed},
                 bytesize: 300,
                 status: :skipped
               },
               "/some/dir/4.CRM" => %FileImport{
                 path: "/some/dir/4.CRM",
                 type: {:video, :raw},
                 bytesize: 400,
                 status: :todo
               }
             }

      assert state.last_event_id == 2
    end

    test "%FileImported{}" do
      # the state is populated:
      assert :ok =
               GenServer.call(@test_tracker, %FilesFound{
                 files: [
                   %File_{
                     path: "/some/dir/3.MP4",
                     type: {:video, :compressed},
                     bytesize: 300
                   },
                   %File_{path: "/some/dir/4.CRM", type: {:video, :raw}, bytesize: 400}
                 ]
               })

      # the FileImported event:
      assert :ok =
               GenServer.call(@test_tracker, %FileImported{
                 path: "/some/dir/3.MP4"
               })

      state = ImportTracker.get_state(@test_tracker)

      assert state.files_by_path == %{
               "/some/dir/3.MP4" => %FileImport{
                 path: "/some/dir/3.MP4",
                 type: {:video, :compressed},
                 bytesize: 300,
                 status: :imported
               },
               "/some/dir/4.CRM" => %FileImport{
                 path: "/some/dir/4.CRM",
                 type: {:video, :raw},
                 bytesize: 400,
                 status: :todo
               }
             }

      assert state.last_event_id == 2
    end

    test "%ImportFinished{}" do
      # the FileImported event:
      assert :ok =
               GenServer.call(@test_tracker, %ImportFinished{
                 import_id: 1,
                 total_files: 2,
                 skipped_count: 3,
                 imported_count: 4,
                 imported_bytes: 5
               })

      state = ImportTracker.get_state(@test_tracker)

      assert state == %{files_by_path: %{}, last_event_id: 1, import_status: :done}
    end
  end
end
