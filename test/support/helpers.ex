defmodule Photor.TestHelpers do
  import ExUnit.Callbacks, only: [on_exit: 1]

  import Mox
  import Photor.Factory

  alias Photor.Imports.Import
  alias Photor.Metadata.MockExiftool

  @doc """
  Changes the application configuration for a test, and reverts the change when
  the test is done.

  NOTE: Not to be used with async tests due to the stateful aspect of it.
  """
  def override_test_config(app \\ :photor, key, config_override) do
    original_config = Application.get_env(app, key, [])

    new_config =
      case original_config do
        c when is_list(c) ->
          # when the value associated to this key is a list, then update the list:
          c |> Keyword.merge(config_override)

        _ ->
          # for any other values, replace it entirely:
          config_override
      end

    # apply the change:
    Application.put_env(app, key, new_config)

    # revert when the test finishes:
    on_exit(fn ->
      Application.put_env(app, key, original_config)
    end)

    new_config
  end

  @photor_dir Application.compile_env!(:photor, :photor_dir)

  @doc """

  """
  def prepare_test_import(%Import{} = import) do
    insert(:photo,
      # partial hash of the image with "fake content 1" as content, the photo1:
      partial_sha256_hash: "muwccakpggvzomnerukl2ub7y6xv7bumjbvqvqxfnnagk5nuqrsq",
      import: import
    )

    # Mock the metadata read for each file
    MockExiftool
    |> expect(:read_as_json, 2, fn path ->
      filename = Path.basename(path)

      {:ok,
       %{
         "FileName" => filename,
         "CreateDate" => "2023-06-15 10:30:00",
         "MIMEType" => "image/jpeg"
       }}
    end)

    on_exit(fn ->
      # empty the photor_dir
      File.ls!(@photor_dir)
      |> Enum.each(fn thing ->
        Path.join(@photor_dir, thing) |> File.rm_rf!()
      end)
    end)
  end

  # TODO: validate those events with an assertion of equality after collecting events in importer_test.exs
  def expected_events(%Import{} = import) do
    [
      %Photor.Imports.Events.NewImport{
        import_id: import.id,
        started_at: import.started_at,
        source_dir: "test/assets/import_source"
      },
      %Photor.Imports.Events.FilesFound{
        import_id: import.id,
        files: [
          %Photor.Files.File{
            path: "test/assets/import_source/photo1.jpg",
            type: %{type: :compressed, extension: "jpg", medium: :photo},
            bytesize: 15,
            access: :read_write
          },
          %Photor.Files.File{
            path: "test/assets/import_source/sub1/photo2.jpg",
            type: %{type: :compressed, extension: "jpg", medium: :photo},
            bytesize: 15,
            access: :read_write
          },
          %Photor.Files.File{
            path: "test/assets/import_source/sub1/sub2/photo3.jpg",
            type: %{type: :compressed, extension: "jpg", medium: :photo},
            bytesize: 15,
            access: :read_write
          }
        ]
      },
      %Photor.Imports.Events.ScanStarted{import_id: import.id},
      %Photor.Imports.Events.FileAlreadyInRepoFound{
        import_id: import.id,
        path: "test/assets/import_source/photo1.jpg"
      },
      %Photor.Imports.Events.FileNotYetInRepoFound{
        import_id: import.id,
        path: "test/assets/import_source/sub1/photo2.jpg"
      },
      %Photor.Imports.Events.FileNotYetInRepoFound{
        import_id: import.id,
        path: "test/assets/import_source/sub1/sub2/photo3.jpg"
      },
      %Photor.Imports.Events.ImportStarted{
        import_id: import.id
      },
      %Photor.Imports.Events.FileImporting{
        import_id: import.id,
        path: "test/assets/import_source/sub1/photo2.jpg"
      },
      %Photor.Imports.Events.FileImported{
        import_id: import.id,
        path: "test/assets/import_source/sub1/photo2.jpg"
      },
      %Photor.Imports.Events.FileImporting{
        import_id: import.id,
        path: "test/assets/import_source/sub1/sub2/photo3.jpg"
      },
      %Photor.Imports.Events.FileImported{
        import_id: import.id,
        path: "test/assets/import_source/sub1/sub2/photo3.jpg"
      },
      %Photor.Imports.Events.ImportFinished{import_id: import.id}
    ]
  end
end
