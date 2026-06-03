defmodule Procession.AI.NPCInteraction.QE5VoiceExpressionExamplesTest do
  use ExUnit.Case, async: true

  @path "priv/training/qe5_voice_expression_examples.jsonl"

  test "QE5 voice expression examples are valid JSONL" do
    examples = load_examples!()

    assert length(examples) >= 30
  end

  test "QE5 examples include natural conversation shape fields" do
    examples = load_examples!()

    example =
      Enum.find(examples, fn example ->
        example["id"] == "qe5_miner_on_edge_unknown_elandra_money"
      end)

    assert example
    assert example["input"]["fallback"] == "I do not know Elandra."
    assert example["input"]["voice_profile"] == "miner"
    assert example["input"]["emotional_state"] == "on_edge"
    assert example["input"]["delivery_style"] == "terse"
    assert example["input"]["conversational_move"] == "ask_followup"
    assert example["expected"] == "Elandra? She looking for money?"
  end

  test "QE5 examples include terse answers follow-up questions and pronouns" do
    expected_lines =
      load_examples!()
      |> Enum.map(& &1["expected"])

    assert "No." in expected_lines
    assert "Who's Elandra?" in expected_lines
    assert "How should I know? I don't follow her around." in expected_lines
    assert "Elandra? She looking for money?" in expected_lines
  end

  defp load_examples! do
    @path
    |> File.stream!()
    |> Enum.map(fn line ->
      line
      |> String.trim()
      |> Jason.decode!()
    end)
  end
end
