defmodule Photor.Photos.ThumbnailsJob do
  alias Photor.Jobs.Job
  alias Photor.Jobs.JobHandler

  @behaviour JobHandler

  # alias Photor.Photos.Thumbnails

  @impl JobHandler
  def execute(%Job{}) do
    :ok
  end
end
