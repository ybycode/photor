defmodule Photor.Metadata.ExiftoolBehaviour do
  @callback read_as_json(String.t()) :: {:ok, map()} | {:error, any()}
end
