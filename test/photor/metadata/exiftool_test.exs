defmodule Photor.Metadata.ExiftoolTest do
  use ExUnit.Case

  alias Photor.TestHelpers
  alias Photor.Metadata.Exiftool

  import ExUnit.CaptureLog

  @ricoh_jpg "test/assets/Ricoh_GRIIIx.JPG"

  describe "exiftool" do
    test "reads from a file and returns a XXX" do
      assert {:ok, _res = %{}} = Exiftool.read_as_json(@ricoh_jpg)
    end

    test "raises when exiftool is not available" do
      # the config is changed to point to some non existent binary:
      TestHelpers.override_test_config(Exiftool,
        exiftool_binary: "/bin/non-existent"
      )

      assert_raise(RuntimeError, ~r/.*non-existent.* executable is not available/, fn ->
        log =
          capture_log(fn ->
            Exiftool.read_as_json("somefile.jpg")
          end)

        assert log == 23
      end)
    end

    test "when a file doesn't exist" do
      log =
        capture_log(fn ->
          assert {:error, reason} = Exiftool.read_as_json("unknown.jpg")
          assert reason =~ "File not found"
        end)

      IO.puts(log)
      assert log =~ "File not found"
      assert log =~ "unknown.jpg"
    end
  end
end
