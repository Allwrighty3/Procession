defmodule Procession.IdTest do
  use ExUnit.Case

  test "generates IDs with a prefix" do
    id = Procession.Id.generate("npc")

    assert is_binary(id)
    assert String.starts_with?(id, "npc_")
  end

  test "generates memory IDs" do
    id = Procession.Id.memory()

    assert is_binary(id)
    assert String.starts_with?(id, "mem_")
  end

  test "generates different IDs" do
    first = Procession.Id.memory()
    second = Procession.Id.memory()

    refute first == second
  end
end
