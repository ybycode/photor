defmodule Photor.Photos.Thumbnails.Job do
  alias Photor.Jobs.Job, as: Job
  alias Photor.Photos.Thumbnails

  @behaviour Photor.Jobs.JobHandler

  @impl true
  def execute(%Job{id: _job_id}) do
    # TODO: 0 here, argument could be removed?
    Thumbnails.create_missing_thumbnails(
      0,
      4,
      5000
    )
  end
end
