defmodule Photor.Photos.Thumbnails do
  @moduledoc """
  Functions for generating thumbnails of photos.
  """

  @default_max_width 800
  @default_max_height 600
  @default_quality 85

  @callback thumbnail_cmd(
              source_path :: String.t(),
              output_path :: String.t(),
              max_width :: integer(),
              max_height :: integer(),
              quality :: integer()
            ) :: String.t()

  @doc """
  Creates a thumbnail from a source image.

  ## Parameters
    - source_path: Path to the source image
    - output_path: Path where the thumbnail should be saved
    - opts: Optional parameters
      - max_width: Maximum width of the thumbnail (default: #{@default_max_width})
      - max_height: Maximum height of the thumbnail (default: #{@default_max_height})
      - quality: JPEG quality (0-100) (default: #{@default_quality})

  ## Returns
    - `{:ok, output_path}` on success
    - `{:error, reason}` on failure
  """
  def create_thumbnail(source_path, output_path, opts \\ []) do
    max_width = Keyword.get(opts, :max_width, @default_max_width)
    max_height = Keyword.get(opts, :max_height, @default_max_height)
    quality = Keyword.get(opts, :quality, @default_quality)

    # Ensure the output directory exists
    output_path |> Path.dirname() |> File.mkdir_p!()

    cmd = impl().thumbnail_cmd(source_path, output_path, max_width, max_height, quality)

    # Traping exits so that if the external command fails, this calling process
    # doesn't die with it and so can report the error.
    Process.flag(:trap_exit, true)

    case :exec.run_link(cmd, [:sync, :stderr]) do
      {:ok, _} ->
        {:ok, output_path}

      {:error, error_info} ->
        # Flush any EXIT messages from the mailbox to ensure they don't leak
        flush_mailbox()

        {:status, os_exit_status} = error_info |> Keyword.fetch!(:exit_status) |> :exec.status()
        # the :stderr field might not be present in all error cases, hence the use of get/2 here.
        err_msg = Keyword.get(error_info, :stderr, nil)

        {:error,
         "Calls to create a thumbnail failed with exit status #{os_exit_status}" <>
           ((err_msg && "and message: #{err_msg}") || "")}
    end
  end

  @doc """
  Returns the module that implements the thumbnail behavior.
  """
  def impl do
    Application.get_env(:photor, __MODULE__, [])
    |> Keyword.get(:impl, Photor.Photos.ThumbnailMagick)
  end

  # Helper function to flush the process mailbox
  defp flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      0 -> :ok
    end
  end
end
