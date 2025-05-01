defmodule Photor.Hasher do
  @moduledoc """
  Computes the SHA-256 hash of the file size (as a string) and the first `nbytes` of the file content.
  """

  @doc """
  Computes the SHA-256 hash of the file size and the first `nbytes` of the file content.

  ## Examples

      iex> Hasher.hash_file_first_bytes("checksum.txt", 0)
      {:ok, "4a44dc15364204a80fe80e9039455cc1608281820fe2b24f1e5233ade6af1dd5"}

      iex> Hasher.hash_file_first_bytes("checksum.txt", 1)
      {:ok, "16dc368a89b428b2485484313ba67a3912ca03f2b2b42429174a4f8b3dc84e44"}

      iex> Hasher.hash_file_first_bytes("checksum.txt", 1000)
      {:ok, "e85655adf07244724785569c2180d8604c81dd6126a502dee002b6c7459322ba"}
  """
  def hash_file_first_bytes(path, nbytes) do
    with {:ok, %{size: size}} <- File.stat(path),
         size_str = Integer.to_string(size),
         {:ok, binary} <- read_first_n_bytes(path, nbytes) do
      digest =
        :crypto.hash_init(:sha256)
        |> :crypto.hash_update(size_str)
        |> :crypto.hash_update(binary)
        |> :crypto.hash_final()

      {:ok, Base.encode16(digest, case: :lower)}
    else
      {:error, reason} ->
        {:error, "Failed to process file: #{format_file_error(reason)}"}
    end
  end

  defp read_first_n_bytes(path, nbytes) do
    File.open(path, [:read, :binary], fn file ->
      case IO.binread(file, nbytes) do
        {:error, reason} -> {:error, reason}
        :eof -> <<>>
        data -> data
      end
    end)
  end

  defp format_file_error(reason) do
    :file.format_error(reason) |> List.to_string()
  end
end
