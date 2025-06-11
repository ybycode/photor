defmodule PhotorWeb.ImportLive.Index do
  use PhotorWeb, :live_view
  alias Photor.Imports

  def mount(_params, _session, socket) do
    # NOTE: consistency issues between initial state and update due to
    # concurrency aren't considered here, given that the received events
    # override entirely the initial state.

    # Subscribe to import updates
    Imports.subscribe_to_import_sessions()

    # Get current imports info
    imports = Imports.get_all_imports_info()

    {:ok, assign(socket, imports: imports)}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold mb-6">Imports</h1>

      <div class="space-y-6">
        <%= if Enum.empty?(@imports) do %>
          <p class="text-gray-500">No imports found.</p>
        <% else %>
          <%= for {_import_id, import} <- Enum.sort_by(@imports, fn {_id, import} -> import.started_at end, {:desc, DateTime}) do %>
            <div class="bg-white shadow rounded-lg p-6">
              <div class="flex justify-between items-center mb-4">
                <h2 class="text-xl font-semibold">Import #{import.import_id}</h2>
                <span class={"px-3 py-1 rounded-full text-sm font-medium #{status_color(import.import_status)}"}>
                  {format_status(import.import_status)}
                </span>
              </div>

              <div class="space-y-3">
                <div class="flex justify-between">
                  <span class="text-gray-500">Started at:</span>
                  <span>{format_datetime(import.started_at)}</span>
                </div>

                <div class="flex justify-between">
                  <span class="text-gray-500">Current file:</span>
                  <span class="truncate max-w-md">
                    <%= if import.current_file_path do %>
                      {import.current_file_path}
                    <% else %>
                      -
                    <% end %>
                  </span>
                </div>

                <div class="flex justify-between">
                  <span class="text-gray-500">Files:</span>
                  <span>
                    {import.files_imported} imported / {import.files_skipped} skipped / {import.total_number_of_files} total
                  </span>
                </div>

                <div class="flex justify-between">
                  <span class="text-gray-500">Progress:</span>
                  <span>
                    {format_bytes(import.imported_bytes + import.skipped_bytes)} / {format_bytes(
                      import.total_bytes
                    )}
                  </span>
                </div>

                <div class="mt-2">
                  <div class="w-full bg-gray-200 rounded-full h-2.5">
                    <div
                      class="bg-blue-600 h-2.5 rounded-full"
                      style={"width: #{progress_percentage(import)}%"}
                    >
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp status_color(status) do
    case status do
      :started -> "bg-blue-100 text-blue-800"
      :scanning -> "bg-purple-100 text-purple-800"
      :importing -> "bg-yellow-100 text-yellow-800"
      :finished -> "bg-green-100 text-green-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp format_status(status) do
    status
    |> to_string()
    |> String.capitalize()
  end

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y %Hh%M")
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 2)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 2)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 2)} KB"
      true -> "#{bytes} bytes"
    end
  end

  defp progress_percentage(import) do
    if import.total_bytes > 0 do
      percentage = (import.imported_bytes + import.skipped_bytes) / import.total_bytes * 100
      Float.round(percentage, 1)
    else
      0
    end
  end

  def handle_info({:import_update, import_id, import_info}, socket) do
    # Update the specific import in the map
    imports = Map.put(socket.assigns.imports, import_id, import_info)
    {:noreply, assign(socket, imports: imports)}
  end
end
