defmodule Photor.Photos.ThumbnailsTest do
  use Photor.DataCase

  alias Photor.Repo
  alias Photor.Photos.Photo
  alias Photor.Photos.Thumbnails
  alias Photor.Photos.Thumbnails.Thumbnail

  import Mox
  import Photor.Factory
  import Photor.TestHelpers
  import Ecto.Query

  import ExUnit.CaptureLog

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "make_thumbnail_path/2" do
    test "works" do
      photo = build(:photo, directory: "one/two", filename: "image.jpg")
      thumbnail = build(:thumbnail, photo: photo, size_name: "medium")

      assert Thumbnails.make_thumbnail_path(photo, thumbnail) ==
               "thumbnails/one/two/image_medium.jpg"
    end
  end

  describe "make_thumbnail_path/3" do
    test "works" do
      directory = "one/two"
      filename = "image.jpg"

      assert Thumbnails.make_thumbnail_path(directory, filename, "large") ==
               "thumbnails/one/two/image_large.jpg"
    end
  end

  describe "create_thumbnail/3" do
    test "creates a thumbnail from a source image" do
      # Setup
      source_path = "test/assets/test_image.jpg"
      output_dir = System.tmp_dir!()
      output_path = Path.join(output_dir, "test_image_thumbnail.jpg")

      # Ensure output file doesn't exist before test
      File.rm(output_path)

      # Register cleanup
      on_exit(fn -> File.rm(output_path) end)

      # Execute
      assert :ok = Thumbnails.create_thumbnail("medium", source_path, output_path)

      # Verify
      assert File.exists?(output_path)

      # Check that the thumbnail was actually created and is smaller than the original
      {:ok, %{size: original_size}} = File.stat(source_path)
      {:ok, %{size: thumbnail_size}} = File.stat(output_path)
      assert thumbnail_size < original_size

      # Test with custom options
      custom_output_path = Path.join(output_dir, "test_image_custom_thumbnail.jpg")
      on_exit(fn -> File.rm(custom_output_path) end)

      assert :ok =
               Thumbnails.create_thumbnail(
                 "large",
                 source_path,
                 custom_output_path
               )

      assert File.exists?(custom_output_path)
    end

    test "process mailbox should be empty after an error" do
      # Setup
      source_path = "test/assets/test_image.jpg"
      output_path = Path.join(System.tmp_dir!(), "test_image_thumbnail.jpg")

      # Mock the implementation module
      override_test_config(:photor, Photor.Photos.Thumbnails, impl: Photor.Photos.ThumbnailMock)

      # Mock the thumbnail_cmd function to return a command that will fail
      expect(Photor.Photos.ThumbnailMock, :thumbnail_cmd, fn _, _, _, _, _ ->
        # Command that will always exit with status 1 (error)
        "false"
      end)

      # Execute with the mock
      result = Thumbnails.create_thumbnail("small", source_path, output_path)

      # Verify the function returns an error
      assert {:error, reason} = result
      assert reason == "Calls to create a thumbnail failed with exit status 1"

      # Verify the process mailbox is empty (no unhandled EXIT messages)
      refute_receive _, 100
    end

    test "returns error when command fails due to missing executable" do
      # Setup
      source_path = "test/assets/test_image.jpg"
      output_path = Path.join(System.tmp_dir!(), "test_image_thumbnail.jpg")

      # Ensure the file doesn't exist before and after the test
      File.rm(output_path)
      on_exit(fn -> File.rm(output_path) end)

      # Mock the implementation module
      override_test_config(:photor, Photor.Photos.Thumbnails, impl: Photor.Photos.ThumbnailMock)

      # Mock the thumbnail_cmd function to return a command with non-existent executable
      expect(Photor.Photos.ThumbnailMock, :thumbnail_cmd, fn _, _, _, _, _ ->
        "non_existent_command_123 -input #{source_path} -output #{output_path}"
      end)

      # Execute with the mock
      result = Thumbnails.create_thumbnail("large", source_path, output_path)

      # Verify
      assert {:error, reason} = result
      assert reason =~ "127"
      assert reason =~ "non_existent_command_123: command not found"
      refute File.exists?(output_path)
    end
  end

  describe "next_missing_thumbnails/2" do
    test "returns a list of inputs for the mising thumbnails, and the next id to look for" do
      [p1, p2 | _] = insert_list(4, :photo, mime_type: "image/jpeg")

      # there's only one thumbnail so far for those photos:
      insert(:thumbnail, photo: p2, size_name: "medium")

      expected_next_id = p2.id + 1

      assert {list, ^expected_next_id} = Thumbnails.next_missing_thumbnails(p1.id, 2)

      assert list ==
               [
                 {%{
                    photo_id: p1.id,
                    directory: p1.directory,
                    filename: p1.filename
                  }, ["large", "medium", "small"]},
                 {%{
                    photo_id: p2.id,
                    directory: p2.directory,
                    filename: p2.filename
                  }, ["large", "small"]}
               ]
    end

    test "returns :done when there's nothing more to create" do
      [_p1, p2] = insert_list(2, :photo)

      assert :done = Thumbnails.next_missing_thumbnails(p2.id + 1, 2)
    end

    test "can return an empty list in some conditions" do
      [p1, p2] = insert_list(2, :photo, mime_type: "image/jpeg")

      # all thumbails exist for p1:
      insert(:thumbnail, photo: p1, size_name: "small")
      insert(:thumbnail, photo: p1, size_name: "medium")
      insert(:thumbnail, photo: p1, size_name: "large")

      # with a nb_photos_max of 1, all found photos have a thumbnail, so nothing to do for this chunk:
      assert {[], next_id} = Thumbnails.next_missing_thumbnails(p1.id, 1)
      assert next_id == p1.id + 1

      # there's still results, in the next page:
      assert {list, next_id} = Thumbnails.next_missing_thumbnails(next_id, 1)
      assert next_id == p2.id + 1

      assert list == [
               {%{
                  photo_id: p2.id,
                  directory: p2.directory,
                  filename: p2.filename
                }, ["large", "medium", "small"]}
             ]
    end
  end

  defp make_blocking_callack(pid) do
    fn size_name, input_path, output_path ->
      send(pid, {self(), size_name, input_path, output_path})

      # now it blocks until it receives a message:
      receive do
        # this is to be able to simulate exceptions:
        :raise ->
          raise ArgumentError, "oh oh"

        # send this to unblocks the process:
        :stop_waiting ->
          :ok
      end
    end
  end

  describe "create_missing_thumbnails/4" do
    test "works duh" do
      # 4 photos are created. So we expect to generate 12 thumbnails
      p1 =
        insert(:photo, directory: "some_dir", filename: "myphoto1.jpg", mime_type: "image/jpeg")

      _p2 =
        insert(:photo, directory: "some_dir", filename: "myphoto2.jpg", mime_type: "image/jpeg")

      _p3 =
        insert(:photo, directory: "some_dir", filename: "myphoto3.jpg", mime_type: "image/jpeg")

      _p4 =
        insert(:photo, directory: "some_dir", filename: "myphoto4.jpg", mime_type: "image/jpeg")

      max_concurrency = 4

      # how many photos are fetched in one go to check for the existence of
      # their related thumbnails
      photos_page_size = 100

      test_pid = self()

      # The function is called in a task because it's blocking, and we don't
      # want to block the test, as it'll be expecting to receive messages:
      test_task =
        Task.async(fn ->
          assert :ok =
                   Thumbnails.create_missing_thumbnails(
                     p1.id,
                     max_concurrency,
                     photos_page_size,
                     make_blocking_callack(test_pid)
                   )
        end)

      # 4 processes are started to make thumbnails. They first work on making
      # the large ones:
      assert_receive {pid1, "large", "test/photos_repo/some_dir/myphoto1.jpg",
                      "test/photos_repo/thumbnails/some_dir/myphoto1_large.jpg"}

      assert_receive {pid2, "large", "test/photos_repo/some_dir/myphoto2.jpg",
                      "test/photos_repo/thumbnails/some_dir/myphoto2_large.jpg"}

      assert_receive {pid3, "large", "test/photos_repo/some_dir/myphoto3.jpg",
                      "test/photos_repo/thumbnails/some_dir/myphoto3_large.jpg"}

      assert_receive {pid4, "large", "test/photos_repo/some_dir/myphoto4.jpg",
                      "test/photos_repo/thumbnails/some_dir/myphoto4_large.jpg"}

      # nothing else is coming, since all 4 large thumbnails were processed and
      # the function is now waiting
      refute_receive _

      # we unblock the 4 processes so that they can continue:
      Enum.each([pid1, pid2, pid3, pid4], fn pid ->
        send(pid, :stop_waiting)
      end)

      # the same processes now work on making the medium sized thumbnails,
      # based on the large ones:
      Enum.each([{1, pid1}, {2, pid2}, {3, pid3}, {4, pid4}], fn {n, pid} ->
        # the test callback should be dealing with medium formats now:
        exp_input = "test/photos_repo/thumbnails/some_dir/myphoto#{n}_large.jpg"
        exp_output = "test/photos_repo/thumbnails/some_dir/myphoto#{n}_medium.jpg"

        assert_receive {^pid, "medium", ^exp_input, ^exp_output}
      end)

      # we unblock the 4 processes so that they can continue:
      Enum.each([pid1, pid2, pid3, pid4], fn pid ->
        send(pid, :stop_waiting)
      end)

      # the same processes now work on making the small sized thumbnails,
      # based on the medium ones:
      Enum.each([{1, pid1}, {2, pid2}, {3, pid3}, {4, pid4}], fn {n, pid} ->
        # the test callback should be dealing with medium formats now:
        exp_input = "test/photos_repo/thumbnails/some_dir/myphoto#{n}_medium.jpg"
        exp_output = "test/photos_repo/thumbnails/some_dir/myphoto#{n}_small.jpg"

        assert_receive {^pid, "small", ^exp_input, ^exp_output}
      end)

      # nothing else is coming, since all 4 thumbnails are being processed
      refute_receive _

      # The 4 are unblocked:
      Enum.each([pid1, pid2, pid3, pid4], fn pid ->
        send(pid, :stop_waiting)
      end)

      # the test task should terminate quickly now. Otherwise something is wrong:
      Task.await(test_task, 20)

      # each photo should now have 3 thumbnails in DB too:
      p1_id = p1.id

      p1_db =
        from(p in Photo,
          where: p.id == ^p1_id,
          left_join: t in assoc(p, :thumbnails),
          preload: [thumbnails: t]
        )
        |> Repo.one!()

      assert length(p1_db.thumbnails) == 3
    end

    test "logs if one raises" do
      p1 =
        insert(:photo, directory: "some_dir", filename: "myphoto.jpg", mime_type: "image/jpeg")

      max_concurrency = 4

      # how many photos are fetched in one go to check for the existence of
      # their related thumbnails
      photos_page_size = 100

      test_pid = self()

      # The function is called in a task because it's blocking (because of the
      # make_blocking_callack it's given), and we don't want to block the test,
      # as it'll be expecting to receive messages:
      test_task =
        Task.async(fn ->
          assert :ok =
                   Thumbnails.create_missing_thumbnails(
                     p1.id,
                     max_concurrency,
                     photos_page_size,
                     make_blocking_callack(test_pid)
                   )
        end)

      log =
        capture_log(fn ->
          # the callback is expected to be called first for the large thumbnail
          # generation. The process pid is binded to a variable, and the
          # process is unblocked, as if the execution was successful:
          assert_receive {pid1, "large", _, _}
          send(pid1, :stop_waiting)

          # for the medium, we simulate an exception by asking the callback to raise:
          assert_receive {^pid1, "medium", _, _}
          send(pid1, :raise)

          # the last one is unblocked, like the first one:
          assert_receive {^pid1, "small", _, _}
          send(pid1, :stop_waiting)

          Task.await(test_task)
        end)

      # the exception should have been logged:
      assert log =~ "[error]"
      assert log =~ "photo id #{p1.id}"
      assert log =~ "myphoto_large.jpg"
      assert log =~ "ArgumentError"

      refute_receive _

      # although one failed, the others should have succeeded, which should
      # show as Thumbnail entries in the DB:

      p1_id = p1.id

      generated_thumbnails =
        from(t in Thumbnail, where: t.photo_id == ^p1_id)
        |> Repo.all()
        |> Enum.map(& &1.size_name)
        |> Enum.sort()

      assert generated_thumbnails == ["large", "small"]
    end
  end
end
