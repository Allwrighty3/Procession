defmodule Procession.AI.NPCInteraction.FakeExpressionAdapterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.FakeExpressionAdapter

  test "returns configured response" do
    assert FakeExpressionAdapter.generate("prompt", response: "Mira keeps the inn.") ==
             {:ok, "Mira keeps the inn."}
  end

  test "returns default response when no response is configured" do
    assert FakeExpressionAdapter.generate("prompt", []) ==
             {:ok, "I don't know enough to say that differently."}
  end
end
