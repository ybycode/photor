defmodule Photor.HasherTest do
  use ExUnit.Case, async: true

  alias Photor.Hasher

  @file_1024_bytes "test/assets/1024_bytes.txt"
  @file_empty "test/assets/empty"

  describe "hash_file_first_bytes/2" do
    test "test whole file (nbytes = 1024)" do
      expected = "33mombm7wicj2tzaith4thsh2bxu3zerhrg7zbzi32qvcnc2btna"
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_1024_bytes, 1024)
    end

    test "test more bytes (nbytes = 2048)" do
      expected = "33mombm7wicj2tzaith4thsh2bxu3zerhrg7zbzi32qvcnc2btna"
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_1024_bytes, 2048)
    end

    test "test first byte (nbytes = 1)" do
      expected = "cyyppbhq37o5fyyxkk5ljcpx6suqtozcqebhsmfqhbaeborqjndq"
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_1024_bytes, 1)
    end

    test "test no bytes (nbytes = 0)" do
      expected = "4opo7axwdmq6fz7xml6mimdtldywk5l7fz36zbk5ngjppyazdeza"
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_1024_bytes, 0)
    end

    test "test empty file" do
      expected = "l7wowzx7zbxtrwkspbwg22lmphbnxqrz3vhjdndhfhltuj73k7uq"
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_empty, 1024)
      assert {:ok, ^expected} = Hasher.hash_file_first_bytes(@file_empty, 0)
    end

    test "file does not exist" do
      assert {:error, _} = Hasher.hash_file_first_bytes("nonexistent.txt", 100)
    end
  end
end
