defmodule Photor.Photos.Thumbnails do
  import Ecto.Query

  alias Photor.Photos.Photo
  alias Photor.Photos.Thumbnails.Supervisor, as: ThumbnailsSupervisor
  alias Photor.Photos.Thumbnails.Thumbnail
  alias Photor.Photos.Thumbnails.ThumbnailMagick
  alias Photor.Repo

  require Logger

  @moduledoc """
  Functions for generating thumbnails of photos.
  """

  @default_quality 85

  # NOTE: the order of size_names matter here, since they define the SQL order
  # result, and smaller thumbnails are generated based on their bigger sibling.
  @size_names ["large", "medium", "small"]

  @callback thumbnail_cmd(
              source_path :: String.t(),
              output_path :: String.t(),
              max_width :: integer(),
              max_height :: integer(),
              quality :: integer()
            ) :: String.t()

  @doc """
  Returns the module that implements the thumbnail behavior.
  """
  def impl do
    Application.get_env(:photor, __MODULE__, [])
    |> Keyword.get(:impl, ThumbnailMagick)
  end

  @doc """
  Given a `%Photo{}` and a `%Thumbnail{}`, returns the path (relative to PHOTOR_DIR) of the thumbnail.
  """
  def make_thumbnail_path(
        %Photo{directory: directory, filename: filename},
        %Thumbnail{
          size_name: size_name
        }
      ) do
    make_thumbnail_path(directory, filename, size_name)
  end

  def make_thumbnail_path(directory, filename, size_name)
      when size_name in @size_names do
    extname = Path.extname(filename)

    basename = Path.basename(filename, extname)
    filename = "#{basename}_#{size_name}#{extname}"

    Path.join(["thumbnails", directory, filename])
  end

  @doc """
  Creates a thumbnail from a source image.

  ## Parameters
    - source_path: Path to the source image
    - output_path: Path where the thumbnail should be saved
    - opts: Optional parameters

  ## Returns
    - `:ok` on success
    - `{:error, reason}` on failure
  """
  def create_thumbnail("small", source_path, output_path) do
    create_thumbnail(source_path, output_path, 120, 120)
  end

  def create_thumbnail("medium", source_path, output_path) do
    create_thumbnail(source_path, output_path, 800, 800)
  end

  def create_thumbnail("large", source_path, output_path) do
    create_thumbnail(source_path, output_path, 2000, 2000)
  end

  defp create_thumbnail(
         source_path,
         output_path,
         max_width,
         max_height
       ) do
    # Ensure the output directory exists
    output_path |> Path.dirname() |> File.mkdir_p!()

    cmd = impl().thumbnail_cmd(source_path, output_path, max_width, max_height, @default_quality)

    # Traping exits so that if the external command fails, this calling process
    # doesn't die with it and so can report the error.
    Process.flag(:trap_exit, true)

    # Using the erlang :erlexec library to nicely run external commands. This
    # among other benefits allows to not create zombie OS processes if the app
    # process crashes.
    case :exec.run_link(cmd, [:sync, :stderr]) do
      {:ok, _} ->
        :ok

      {:error, error_info} ->
        # because the process is trapping messages (see above), in case of error, run_link/2 receives an :EXIT message. We consume it to avoid them to accumulate and leak memory.
        # See https://hexdocs.pm/erlexec/exec.html#run_link/3.
        # Note: this slows down the function execution, but only when errors
        # happen, which shouldn't happen in the first place.
        consume_exit_message()

        {:status, os_exit_status} = error_info |> Keyword.fetch!(:exit_status) |> :exec.status()
        # the :stderr field might not be present in all error cases, hence the use of get/2 here.
        err_msg = Keyword.get(error_info, :stderr, nil)

        {:error,
         "Calls to create a thumbnail failed with exit status #{os_exit_status}" <>
           ((err_msg && "and message: #{err_msg}") || "")}
    end
  end

  defp find_photo_chunk_last_id(photo_id_from, nb_photos_max) do
    from(
      p in subquery(
        from(
          p in Photo,
          order_by: p.id,
          where: p.id >= ^photo_id_from,
          limit: ^nb_photos_max,
          select: p.id
        )
      ),
      select: max(p.id)
    )
    |> Repo.one!()
  end

  @fragment_sizes Enum.with_index(@size_names)
                  |> Enum.map(fn
                    {size_name, 0} -> "SELECT '#{size_name}' AS size"
                    {size_name, _} -> "SELECT '#{size_name}'"
                  end)
                  |> Enum.join(" UNION ALL ")

  @doc """
  Returns a tuple `{query, next_id}` where `query` is an Ecto query to n
  """
  def next_missing_thumbnails(photo_id_from, nb_photos_max)
      when is_integer(photo_id_from) and is_integer(nb_photos_max) do
    case find_photo_chunk_last_id(photo_id_from, nb_photos_max) do
      nil ->
        :done

      photo_chunk_last_id ->
        # the list of expected thumbnails for the considered photos. The cross_join with the fragment is used to generate 3 expected thumbnails per photo (3 different sizes):
        expected =
          from(
            p in Photo,
            cross_join: fragment(@fragment_sizes),
            where: p.mime_type == "image/jpeg",
            where: p.id >= ^photo_id_from and p.id <= ^photo_chunk_last_id,
            select: %{
              photo_id: p.id,
              directory: p.directory,
              filename: p.filename,
              size_name: fragment("size")
            }
          )

        # to find the missing ones, we left join photos and the expected
        # thumbnails. The missing thumbnails are the resulting rows where the
        # thumbnail id is null:
        missing_thumbnails =
          from(s in subquery(expected),
            left_join: t in Thumbnail,
            on: t.photo_id == s.photo_id and t.size_name == s.size_name,
            where: is_nil(t.id),
            select: s
          )
          |> Repo.all()
          |> Enum.chunk_by(& &1.photo_id)
          |> Enum.map(fn group ->
            [%{photo_id: photo_id, directory: directory, filename: filename} | _] = group
            missing_sizes = Enum.map(group, & &1.size_name)
            {%{photo_id: photo_id, directory: directory, filename: filename}, missing_sizes}
          end)

        # A tuple is returned, where the second value is the photo id to start
        # at in the next page:
        {missing_thumbnails, photo_chunk_last_id + 1}
    end
  end

  @default_photo_chunk_page_size 1000
  @doc """
  Queries the database to find photos with missing thumbnails, and creates them.

  The `create_thumbnail_fn` argument is for tests only, it allows to plug in
  any custom function for testing the behaviour.
  """
  def create_missing_thumbnails(
        photo_id_from \\ 0,
        max_concurrency \\ 4,
        photo_chunk_page_size \\ @default_photo_chunk_page_size,
        create_thumbnail_fn \\ &create_thumbnail/3
      ) do
    # TODO: photos could also be streamed (with Repo.stream/2) instead of all at once.
    # TODO info: ** (Ecto.QueryError) preloads are not supported on streams in query
    case next_missing_thumbnails(
           photo_id_from,
           photo_chunk_page_size
         ) do
      :done ->
        # nothing to do
        # TODO: branch untested
        :ok

      {missing_thumbnails, photo_next_chunk_first_id} ->
        photor_dir =
          Application.fetch_env!(
            :photor,
            :photor_dir
          )

        Task.Supervisor.async_stream_nolink(
          ThumbnailsSupervisor,
          missing_thumbnails,
          fn {%{photo_id: photo_id, directory: directory, filename: filename}, missing_sizes} ->
            Enum.each(missing_sizes, fn size_name ->
              # thumbnails are generated from the directly bigger source,
              # whether original, or bigger thumbnail:
              photo_input_path =
                Path.join(
                  photor_dir,
                  case size_name do
                    "large" ->
                      Path.join([directory, filename])

                    "medium" ->
                      make_thumbnail_path(directory, filename, "large")

                    "small" ->
                      make_thumbnail_path(directory, filename, "medium")
                  end
                )

              thumbnail_path =
                Path.join(
                  photor_dir,
                  make_thumbnail_path(directory, filename, size_name)
                )

              try do
                create_thumbnail_fn.(size_name, photo_input_path, thumbnail_path)
              rescue
                exception ->
                  Logger.error(
                    "Thumbnail creation failed for photo id #{photo_id} (input file: #{inspect(photo_input_path)}): #{inspect(exception)}"
                  )

                  {:raised, exception}
              else
                :ok ->
                  # on success, insert a Thumbnail:
                  # TODO: can the thumbnail exist already?
                  # TODO: unique indexes are needed.
                  Thumbnail.create_changeset(%{
                    photo_id: photo_id,
                    width: -1,
                    height: -1,
                    size_name: size_name
                  })
                  |> Repo.insert()

                {:error, reason} = err ->
                  Logger.error(reason)
                  err
              end
            end)
          end,
          max_concurrency: max_concurrency,
          timeout: 30_000
        )
        |> Stream.run()

        create_missing_thumbnails(
          photo_next_chunk_first_id,
          max_concurrency,
          photo_chunk_page_size,
          create_thumbnail_fn
        )

        :ok
    end
  end

  # Helper function to flush the process mailbox
  defp consume_exit_message do
    receive do
      {:EXIT, _os_pid, _status} -> :ok
    after
      1000 -> raise(RuntimeError, "Exit message not received. This shouldn't happen.")
    end
  end
end
