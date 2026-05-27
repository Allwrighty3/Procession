defmodule Procession.MemoryTest do
  use ExUnit.Case

  alias Procession.Memory

  describe "remember_medium/3" do
    test "adds newest memory to the front" do
      existing_memory = [
        %{content: "Old message"}
      ]

      new_message = %{content: "New message"}

      result = Memory.remember_medium(existing_memory, new_message)

      assert result == [
        %{content: "New message"},
        %{content: "Old message"}
      ]
    end

    test "keeps only the default 50 most recent memories" do
      existing_memory =
        for n <- 1..50 do
        %{content: "Message #{n}"}
        end

      new_message = %{content: "Message 51"}

      result = Memory.remember_medium(existing_memory, new_message)

      assert length(result) == 50
      assert hd(result).content == "Message 51"
      assert List.last(result).content == "Message 49"
    end

    test "supports a custom memory limit" do
      result =
        []
        |> Memory.remember_medium(%{content: "One"}, 2)
        |> Memory.remember_medium(%{content: "Two"}, 2)
        |> Memory.remember_medium(%{content: "Three"}, 2)

      assert result == [
        %{content: "Three"},
        %{content: "Two"}
      ]
    end

    test "allows an empty starting memory list" do
      result = Memory.remember_medium([], %{content: "First memory"})

      assert result == [
        %{content: "First memory"}
      ]
    end
  end

  describe "remember_short/3" do
    test "adds newest memory to the front" do
      existing_memory = [
        %{content: "Old message"}
      ]

      new_message = %{content: "New message"}

      result = Memory.remember_short(existing_memory, new_message)

      assert result == [
        %{content: "New message"},
        %{content: "Old message"}
      ]
    end

    test "keeps only the default 10 most recent memories" do
      existing_memory =
        for n <- 1..10 do
        %{content: "Message #{n}"}
        end

      new_message = %{content: "Message 11"}

      result = Memory.remember_short(existing_memory, new_message)

      assert length(result) == 10
      assert hd(result).content == "Message 11"
      assert List.last(result).content == "Message 9"
    end

    test "supports a custom memory limit" do
      result =
        []
        |> Memory.remember_short(%{content: "One"}, 2)
        |> Memory.remember_short(%{content: "Two"}, 2)
        |> Memory.remember_short(%{content: "Three"}, 2)

      assert result == [
        %{content: "Three"},
        %{content: "Two"}
      ]
    end

    test "allows an empty starting memory list" do
      result = Memory.remember_short([], %{content: "First memory"})

      assert result == [
        %{content: "First memory"}
      ]
    end
  end

  describe "remember_short_with_overflow/3" do
    test "returns updated short memory and empty overflow when under the limit" do
      {short_memory, overflow} =
        Memory.remember_short_with_overflow(
          [%{content: "Old"}],
          %{content: "New"},
          3
        )

      assert short_memory == [
        %{content: "New"},
        %{content: "Old"}
      ]

      assert overflow == []
    end

    test "returns overflowed memories when over the limit" do
      existing_memory = [
        %{content: "Message 1"},
        %{content: "Message 2"},
        %{content: "Message 3"}
      ]

      {short_memory, overflow} =
        Memory.remember_short_with_overflow(
          existing_memory,
          %{content: "Message 4"},
          3
        )

      assert short_memory == [
        %{content: "Message 4"},
        %{content: "Message 1"},
        %{content: "Message 2"}
      ]

      assert overflow == [
        %{content: "Message 3"}
      ]
    end

    test "supports custom limits" do
      {short_memory, overflow} =
        Memory.remember_short_with_overflow(
          [
            %{content: "Two"},
            %{content: "One"}
          ],
          %{content: "Three"},
          2
        )

      assert short_memory == [
        %{content: "Three"},
        %{content: "Two"}
      ]

      assert overflow == [
        %{content: "One"}
      ]
    end
  end
end
