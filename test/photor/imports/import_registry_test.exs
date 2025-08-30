defmodule Photor.Imports.ImportRegistryTest do
  use ExUnit.Case

  alias Photor.Imports.ImportRegistry

  @test_registry_name :test_registry

  setup do
    start_link_supervised!({Registry, keys: :unique, name: @test_registry_name})

    :ok
  end

  describe "register_session/2, lookup_session/2, list_sessions/2 in one go" do
    test "work" do
      # 2 processes are created, which register themselves to the registry
      # under the names agent-1 and agent-2:
      [pid1, pid2] =
        Enum.map(1..2, fn num ->
          start_supervised!(%{
            id: "p#{num}",
            start:
              {GenServer, :start_link,
               [
                 Agent.Server,
                 fn ->
                   ImportRegistry.register_session("agent-#{num}", @test_registry_name)
                   num
                 end
               ]},
            # don't restart:
            restart: :temporary
          })
        end)

      # list_sessions works:
      list = ImportRegistry.list_sessions(@test_registry_name)
      assert length(list) == 2
      assert pid1 in list
      assert pid2 in list

      # lookup_session works:
      assert {:ok, ^pid1} = ImportRegistry.lookup_session("agent-1", @test_registry_name)
      assert {:ok, ^pid2} = ImportRegistry.lookup_session("agent-2", @test_registry_name)

      # now the process 1 is stopped. The register then shouldn't
      # return it in results:
      :ok = Agent.stop(pid1)

      assert {:error, :not_found} = ImportRegistry.lookup_session("agent-1", @test_registry_name)
      assert {:ok, ^pid2} = ImportRegistry.lookup_session("agent-2", @test_registry_name)

      # list_sessions/2 only lists the pid2:
      assert [^pid2] = ImportRegistry.list_sessions(@test_registry_name)
    end
  end
end
