defmodule Procession.AI.NPCInteraction.ResponseCandidateCleanerTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.ResponseCandidateCleaner

  test "trims whitespace" do
    assert ResponseCandidateCleaner.clean("  Mira keeps the inn.  ") ==
             "Mira keeps the inn."
  end

  test "keeps first line before newline continuation" do
    raw = """
    Mira keeps the inn in Briar Village.
    Mira is the innkeeper out there.
    """

    assert ResponseCandidateCleaner.clean(raw) ==
             "Mira keeps the inn in Briar Village."
  end

  test "removes prompt residue after valid text" do
    raw = "Can't say I've heard of Elandra.\n### Response\nI don't know anyone by that name."

    assert ResponseCandidateCleaner.clean(raw) ==
             "Can't say I've heard of Elandra."
  end

  test "removes constraints residue" do
    raw = "I don't know anyone by that name.\n### Constraints\nNo facts are relevant."

    assert ResponseCandidateCleaner.clean(raw) ==
             "I don't know anyone by that name."
  end

  test "keeps at most two sentences" do
    raw =
      "No, Tobin's not my brother. He's the merchant out by the crossroads. No, Tobin's not my brother again."

    assert ResponseCandidateCleaner.clean(raw) ==
             "No, Tobin's not my brother. He's the merchant out by the crossroads."
  end

  test "returns non-string candidates unchanged" do
    candidate = %{text: "Mira keeps the inn."}

    assert ResponseCandidateCleaner.clean(candidate) == candidate
  end
end
