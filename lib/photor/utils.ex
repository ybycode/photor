defmodule Photor.Utils do
  require Logger

  @doc """
  Generates a random cookie for a distributed node.
  """
  @spec random_cookie() :: atom()
  def random_cookie() do
    :"c_#{Base.url_encode64(:crypto.strong_rand_bytes(39))}"
  end

  @doc """
  Generates a random value for Phoenix secret key base.
  """
  @spec random_secret_key_base() :: String.t()
  def random_secret_key_base() do
    Base.encode64(:crypto.strong_rand_bytes(48))
  end
end
