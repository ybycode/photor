defmodule Photor.Jobs.Job do
  defstruct [
    :id,
    # The module that should perform this job:
    :handler_mod,
    # Current status: "pending", "running", "completed", "failed"
    :status,
    # When the job was created
    :created_at,
    # When the job started running (NULL if not started)
    :started_at,
    # When the job completed (NULL if not completed)
    :completed_at,

    # the number of items (or subjobs) this has to perform
    :nb_items,
    # the number of items (or subjobs) that were completed successfully
    :nb_items_success,
    # the number of items (or subjobs) that failed
    :nb_items_error
  ]
end
