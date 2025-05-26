defmodule Photor.MetadataHelpers do
  @metadata_json_dir "test/assets/metadata_json"

  @doc """
  Loads metadata JSON from a file in the test/assets/metadata_json directory.

  ## Examples

      iex> load_metadata_json("ricoh_griiix_jpg.json")
      {:ok, %{"Make" => "RICOH IMAGING COMPANY, LTD.", ...}}
  """
  def load_metadata_json(filename) do
    path = Path.join(@metadata_json_dir, filename)

    case File.read(path) do
      {:ok, content} ->
        Jason.decode(content)

      {:error, reason} ->
        {:error, "Failed to read metadata JSON file: #{inspect(reason)}"}
    end
  end
end
