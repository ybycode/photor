defmodule Photor.HasherTest do
  use ExUnit.Case, async: true

  alias Photor.Hasher

  @file_1024_bytes "test/assets/1024_bytes.txt"
  @file_empty "test/assets/empty"

  describe "hash_file_first_bytes/2" do
    test "test whole file (nbytes = 1024)" do
      expected = "ded8e6059fb2049d4f2044cfc99e47d06f4de4913c4dfc8728dea151345a0cda"
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_1024_bytes, 1024)
    end

    test "test more bytes (nbytes = 2048)" do
      expected = "ded8e6059fb2049d4f2044cfc99e47d06f4de4913c4dfc8728dea151345a0cda"
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_1024_bytes, 2048)
    end

    test "test first byte (nbytes = 1)" do
      expected = "1630f784f0dfddd2e31752bab489f7f4a909bb2281027930b0384040ba304b47"
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_1024_bytes, 1)
    end

    test "test no bytes (nbytes = 0)" do
      expected = "e39eef82f61b21e2e7f762fcc4307358f165757f2e77ec855d6992f7e0191932"
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_1024_bytes, 0)
    end

    test "test empty file" do
      expected = "5feceb66ffc86f38d952786c6d696c79c2dbc239dd4e91b46729d73a27fb57e9"
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_empty, 1024)
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_empty, 0)
    end

    test "file does not exist" do
      assert {:error, _} = Hasher.hash_file_first_bytes("nonexistent.txt", 100)
    end
  end
end
