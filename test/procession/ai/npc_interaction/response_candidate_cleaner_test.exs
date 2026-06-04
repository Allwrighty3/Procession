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

    context = %{
      "conversational_move" => %{"move" => "answer_only"}
    }

    assert ResponseCandidateCleaner.clean(raw, context) ==
             "No, Tobin's not my brother. He's the merchant out by the crossroads."
  end

  test "returns non-string candidates unchanged" do
    candidate = %{text: "Mira keeps the inn."}

    assert ResponseCandidateCleaner.clean(candidate) == candidate
  end

  test "keeps terse answer to one sentence" do
    candidate = "No. Don't ask me that again."

    context = %{
      "delivery_style" => %{"shape" => "terse"},
      "conversational_move" => %{"move" => "answer_only"}
    }

    assert ResponseCandidateCleaner.clean(candidate, context) == "No."
  end

  test "trims answer-only follow-up drift" do
    candidate = "No. I don't use the word family lightly. Is Tobin related to Mira?"

    context = %{
      "delivery_style" => %{"shape" => "plain"},
      "conversational_move" => %{"move" => "answer_only"}
    }

    assert ResponseCandidateCleaner.clean(candidate, context) ==
             "No. I don't use the word family lightly."
  end

  test "preserves protective warning but trims extra tail" do
    candidate =
      "No. But if you're looking to cause Tobin trouble, choose your next words carefully. I don't play games."

    context = %{
      "delivery_style" => %{"shape" => "sharp"},
      "conversational_move" => %{"move" => "answer_and_warn"}
    }

    assert ResponseCandidateCleaner.clean(candidate, context) ==
             "No. But if you're looking to cause Tobin trouble, choose your next words carefully."
  end

  test "trims redundant challenge premise" do
    candidate = "Do I look like Tobin to you? Do I look like the merchant to you?"

    context = %{
      "delivery_style" => %{"shape" => "terse"},
      "conversational_move" => %{"move" => "challenge_premise"}
    }

    assert ResponseCandidateCleaner.clean(candidate, context) ==
             "Do I look like Tobin to you?"
  end

  test "allows ask-followup response to keep answer and one question" do
    candidate = "I don't know. Is she nice? Is she related to Elandra?"

    context = %{
      "delivery_style" => %{"shape" => "soft"},
      "conversational_move" => %{"move" => "answer_and_question"}
    }

    assert ResponseCandidateCleaner.clean(candidate, context) ==
             "I don't know. Is she nice?"
  end

  test "preserves rhetorical false-premise question chain" do
    candidate = "Tobin? My brother? I'd have better luck adopting a mule."

    context = %{
      "delivery_style" => %{"shape" => "sharp"},
      "conversational_move" => %{"move" => "challenge_premise"}
    }

    assert ResponseCandidateCleaner.clean(candidate, context) ==
             "Tobin? My brother? I'd have better luck adopting a mule."
  end

  test "preserves contemptuous short question setup" do
    candidate = "Tobin? That roadside fool? Not a chance."

    context = %{
      "delivery_style" => %{"shape" => "terse"},
      "conversational_move" => %{"move" => "challenge_premise"}
    }

    assert ResponseCandidateCleaner.clean(candidate, context) ==
             "Tobin? That roadside fool? Not a chance."
  end

  test "keeps short setup question with follow-up question" do
    candidate = "Elandra? She looking for money? I don't have time for this."

    context = %{
      "delivery_style" => %{"shape" => "terse"},
      "conversational_move" => %{"move" => "ask_followup"}
    }

    assert ResponseCandidateCleaner.clean(candidate, context) ==
             "Elandra? She looking for money?"
  end

  test "preserves eager child question chain" do
    candidate = "I don't know! Is she a knight? Does she have a sword?"

    context = %{
      "delivery_style" => %{"shape" => "eager"},
      "conversational_move" => %{"move" => "ask_followup"}
    }

    assert ResponseCandidateCleaner.clean(candidate, context) ==
             "I don't know! Is she a knight? Does she have a sword?"
  end

  test "keeps terse refusal boundary" do
    candidate = "No. Don't ask me that again."

    context = %{
      "delivery_style" => %{"shape" => "terse"},
      "conversational_move" => %{"move" => "refuse"}
    }

    assert ResponseCandidateCleaner.clean(candidate, context) ==
            "No. Don't ask me that again."
  end
end
