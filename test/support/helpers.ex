defmodule Photor.TestHelpers do
  import ExUnit.Callbacks, only: [on_exit: 1]

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
end
