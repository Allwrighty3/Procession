defmodule Procession.AI.MemoryContextTest do
  use ExUnit.Case

  test "select includes up to five recent memories by default" do
    memories =
      for n <- 1..7 do
        %{id: "mem_#{n}", content: "Memory #{n}", importance: 1}
      end

    selected = Procession.AI.MemoryContext.select(memories)

    assert Enum.map(selected, & &1.id) == [
             "mem_1",
             "mem_2",
             "mem_3",
             "mem_4",
             "mem_5"
           ]
  end

  test "select also includes imporatant memories outside the recent window" do
    memories = [
      %{id: "mem_1", content: "Recent memory", importance: 1},
      %{id: "mem_2", content: "Recent memory", importance: 1},
      %{id: "mem_3", content: "Recent memory", importance: 1},
      %{id: "mem_4", content: "Recent memory", importance: 1},
      %{id: "mem_5", content: "Recent memory", importance: 1},
      %{id: "mem_6", content: "Important older memory", importance: 5}
    ]

    selected = Procession.AI.MemoryContext.select(memories)

    assert Enum.map(selected, & &1.id) == [
             "mem_1",
             "mem_2",
             "mem_3",
             "mem_4",
             "mem_5",
             "mem_6"
           ]
  end

  test "select does not duplicated memories that are both recent and important" do
    memories = [
      %{id: "mem_1", content: "Important recent memory", importance: 5}
    ]

    selected = Procession.AI.MemoryContext.select(memories)

    assert selected == memories
  end

  test "select supports custom recent count and minimum importance" do
    memories = [
      %{id: "mem_1", content: "Recent memory", importance: 1},
      %{id: "mem_2", content: "Recent memory", importance: 1},
      %{id: "mem_3", content: "Important memory", importance: 3}
    ]

    selected =
      Procession.AI.MemoryContext.select(memories,
        recent_count: 1,
        minimum_importance: 3
      )

    assert Enum.map(selected, & &1.id) == ["mem_1", "mem_3"]
  end

  test "select returns an empty list for invalid input" do
    assert Procession.AI.MemoryContext.select(nil) == []
    assert Procession.AI.MemoryContext.select(%{}) == []
  end
end
