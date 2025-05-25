defmodule Mix.Tasks.Photor.ExtractMetadata do
  use Mix.Task
  alias Photor.Metadata.Exiftool

  @shortdoc "Extracts metadata from a photo file and saves it as JSON"

  @moduledoc """
  Extracts metadata from a photo file using exiftool and saves it as JSON.

  ## Usage

      mix photor.extract_metadata path/to/photo.jpg [output_filename]

  If output_filename is not provided, it will generate a filename based on the camera make, model, and file extension.
  The output directory is test/assets/metadata_json/.

  ## Examples

      mix photor.extract_metadata path/to/ricoh_photo.jpg
      # Saves to test/assets/metadata_json/ricoh_griiix_jpg.json

      mix photor.extract_metadata path/to/fuji_photo.raf custom_output.json
      # Saves to test/assets/metadata_json/custom_output.json
  """

  @default_output_dir "test/assets/metadata_json"

  def run(args) do
    case args do
      [photo_path] ->
        extract_and_save(photo_path, nil)

      [photo_path, output_filename] ->
        extract_and_save(photo_path, output_filename)

      _ ->
        Mix.shell().error(
          "Usage: mix photor.extract_metadata path/to/photo.jpg [output_filename]"
        )
    end
  end

  defp extract_and_save(photo_path, output_filename) do
    Mix.shell().info("Extracting metadata from #{photo_path}...")

    case Exiftool.read_as_json(photo_path) do
      {:ok, metadata} ->
        output_filename = output_filename || generate_output_filename(photo_path, metadata)

        # Combine with default output directory
        output_path = Path.join(@default_output_dir, output_filename)

        formatted_json = Jason.encode!(metadata, pretty: true)
        File.write!(output_path, formatted_json)

        Mix.shell().info("Metadata saved to #{output_path}")

      {:error, reason} ->
        Mix.shell().error("Failed to extract metadata: #{inspect(reason)}")
    end
  end

  defp generate_output_filename(photo_path, metadata) do
    # Extract make and model from metadata
    make = metadata["Make"] || "unknown"
    model = metadata["Model"] || "unknown"

    # Clean up make and model for filename
    make = make |> String.replace(~r/[^a-zA-Z0-9]/, "")
    model = model |> String.replace(~r/[^a-zA-Z0-9]/, "")

    # Get file extension
    ext = photo_path |> Path.extname() |> String.downcase() |> String.replace(".", "")

    # Generate filename
    "#{make}_#{model}_#{ext}.json"
  end
end
