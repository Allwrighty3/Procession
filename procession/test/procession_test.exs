defmodule ProcessionTest do
  use ExUnit.Case
  doctest Procession

  test "greets the world" do
    assert Procession.hello() == :world
  end
end
