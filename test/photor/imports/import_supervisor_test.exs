defmodule Photor.Imports.ImportSupervisorTest do
  use Photor.DataCase

  alias Photor.Imports.ImportSupervisor
  alias Photor.Imports.ImportRegistry
  import Photor.Factory

  describe "start_link/1" do
    test "its process name can be forced via options" do
      assert {:ok, pid} = ImportSupervisor.start_link(name: :hello_supervisor)
      assert Process.whereis(:hello_supervisor) == pid
    end
  end

  @test_supervisor_name :whatsup

  defp setup_supervisor(_ctx) do
    # this starts a supervisor dedicated to this test, to not use the one
    # started by the application
    start_link_supervised!({ImportSupervisor, [name: @test_supervisor_name]})

    :ok
  end

  describe "start_import_session/1" do
    setup [:setup_supervisor]

    test "returns {:ok, pid} with pid of the created GenServer" do
      import = insert(:import)

      assert {:ok, pid} = ImportSupervisor.start_import_session(import, @test_supervisor_name)

      assert Supervisor.count_children(@test_supervisor_name) == %{
               active: 1,
               workers: 1,
               supervisors: 0,
               specs: 1
             }

      # the same pid is returned by the Registry:
      assert {:ok, ^pid} = ImportRegistry.lookup_session(import.id)
    end

    test "returns {:error, xyz} with an already started import" do
      import = insert(:import)

      assert {:ok, pid} = ImportSupervisor.start_import_session(import, @test_supervisor_name)

      assert {:error, {:already_started, ^pid}} =
               ImportSupervisor.start_import_session(import, @test_supervisor_name)
    end
  end

  describe "stop_import_session/1" do
    setup [:setup_supervisor]

    test "returns {:ok, pid} with pid of the created GenServer" do
      import = insert(:import)
      assert {:ok, _pid} = ImportSupervisor.start_import_session(import, @test_supervisor_name)
      assert :ok = ImportSupervisor.stop_import_session(import.id, @test_supervisor_name)

      assert Supervisor.count_children(@test_supervisor_name) == %{
               active: 0,
               workers: 0,
               supervisors: 0,
               specs: 0
             }
    end
  end
end
