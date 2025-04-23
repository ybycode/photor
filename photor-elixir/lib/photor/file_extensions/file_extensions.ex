defmodule Photor.FileExtensions do
  @doc """
  Given a file extension, returns a 2-tuple `{a, b}` where:
  - `a` is either `:photo` or `:video`,
  - `b` is either `:compressed` or `:raw`.
  """
  def extension_info(ext)

  extensions_data = Application.compile_env(:photor, __MODULE__)[:data]

  for {medium, type} <- [
        {:photo, :compressed},
        {:photo, :raw},
        {:video, :compressed},
        {:video, :raw}
      ] do
    extensions = extensions_data[{medium, type}]

    extensions =
      Enum.map(extensions, &String.downcase/1) ++ Enum.map(extensions, &String.upcase/1)

    def extension_info(ext) when ext in unquote(extensions) do
      {unquote(medium), unquote(type)}
    end
  end
end
