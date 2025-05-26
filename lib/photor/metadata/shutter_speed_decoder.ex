defmodule Photor.Metadata.ShutterSpeedDecoder do
  def decode(nil), do: {:ok, nil}

  def decode(value) when is_binary(value), do: {:ok, value}

  def decode(value) when is_number(value) do
    {:ok, to_string(value)}
  end

  def decode(_value) do
    {:error, "Expected a string or a number for shutter speed"}
  end
end
