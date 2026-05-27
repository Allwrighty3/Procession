defmodule Procession.MemoryTest do
  use ExUnit.Case

  alias Procession.Memory

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
end
