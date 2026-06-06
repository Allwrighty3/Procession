defmodule Mix.Tasks.Procession.Training.ReviewToSftTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @task "procession.training.review_to_sft"

  test "converts reviewed rows into SFT reinforcement rows" do
    reviewed_path = "tmp/training_reviews/review_to_sft_reviewed.jsonl"
    out_path = "tmp/training_exports/review_to_sft_output.jsonl"
    sft_path = "tmp/training_exports/review_to_sft_source_sft.jsonl"

    File.mkdir_p!(Path.dirname(reviewed_path))
    File.mkdir_p!(Path.dirname(out_path))
    File.mkdir_p!(Path.dirname(sft_path))
    File.rm(sft_path)
    File.rm(reviewed_path)
    File.rm(out_path)

    rows = [
      %{
        "id" => "row_pass",
        "phase" => "qe7c",
        "training_run" => "model_a",
        "eval_run" => "eval_a",
        "eval_set" => "exact_rows",
        "prompt" => "Prompt A",
        "expected" => "Corvin.",
        "raw_generated" => "Corvin.",
        "rating" => "pass",
        "error_tags" => [],
        "training_note" => "",
        "human_reviewed" => true,
        "metadata" => %{"category" => "source_category"}
      },
      %{
        "id" => "row_fail",
        "phase" => "qe7c",
        "training_run" => "model_a",
        "eval_run" => "eval_a",
        "eval_set" => "exact_rows",
        "prompt" => "Prompt B",
        "expected" => "No.",
        "raw_generated" => "No. Are you lost?",
        "rating" => "fail",
        "error_tags" => ["followup_not_allowed"],
        "training_note" => "answer_only should not add a follow-up.",
        "human_reviewed" => true,
        "metadata" => %{"category" => "source_category"}
      }
    ]

    write_jsonl!(reviewed_path, rows)

    sft_rows = [
      %{
        "id" => "row_pass",
        "prompt" => "Prompt A",
        "completion" => "Old A.",
        "text" => "Prompt A\nOld A.",
        "metadata" => %{"category" => "source_category"}
      },
      %{
        "id" => "row_fail",
        "prompt" => "Prompt B",
        "completion" => "Old B.",
        "text" => "Prompt B\nOld B.",
        "metadata" => %{"category" => "source_category"}
      }
    ]

    write_jsonl!(sft_path, sft_rows)

    output =
      capture_io(fn ->
        Mix.Task.rerun(@task, [
          "--reviewed",
          reviewed_path,
          "--sft",
          sft_path,
          "--out",
          out_path,
          "--category",
          "npc_interaction_qe7d_reviewed_memory_expression"
        ])
      end)

    assert output =~ "Reviewed rows: 2"
    assert output =~ "Selected rows: 2"
    assert output =~ "Wrote SFT rows: 2"

    sft_rows = read_jsonl!(out_path)

    assert length(sft_rows) == 2

    pass_row = Enum.find(sft_rows, &(&1["id"] == "review_reinforcement_row_pass"))
    fail_row = Enum.find(sft_rows, &(&1["id"] == "review_reinforcement_row_fail"))

    assert pass_row["prompt"] == "Prompt A"
    assert pass_row["completion"] == "Corvin."
    assert pass_row["text"] == "Prompt A\nCorvin."
    assert pass_row["metadata"]["category"] == "npc_interaction_qe7d_reviewed_memory_expression"
    assert pass_row["metadata"]["review_rating"] == "pass"
    assert pass_row["metadata"]["reinforcement_source_id"] == "row_pass"

    assert fail_row["prompt"] == "Prompt B"
    assert fail_row["completion"] == "No."
    assert fail_row["metadata"]["review_error_tags"] == ["followup_not_allowed"]

    assert fail_row["metadata"]["review_training_note"] ==
             "answer_only should not add a follow-up."

    assert fail_row["metadata"]["raw_generated"] == "No. Are you lost?"
  end

  test "filters rows by rating and tag" do
    reviewed_path = "tmp/training_reviews/review_to_sft_filtered.jsonl"
    out_path = "tmp/training_exports/review_to_sft_filtered_output.jsonl"
    sft_path = "tmp/training_exports/review_to_sft_filtered_source_sft.jsonl"

    File.mkdir_p!(Path.dirname(reviewed_path))
    File.mkdir_p!(Path.dirname(out_path))
    File.mkdir_p!(Path.dirname(sft_path))
    File.rm(sft_path)
    File.rm(reviewed_path)
    File.rm(out_path)

    rows = [
      %{
        "id" => "row_pass",
        "prompt" => "Prompt A",
        "expected" => "A.",
        "rating" => "pass",
        "error_tags" => []
      },
      %{
        "id" => "row_fail_over",
        "prompt" => "Prompt B",
        "expected" => "B.",
        "rating" => "fail",
        "error_tags" => ["over_disclosure"]
      },
      %{
        "id" => "row_fail_tone",
        "prompt" => "Prompt C",
        "expected" => "C.",
        "rating" => "fail",
        "error_tags" => ["tone_mismatch"]
      }
    ]

    write_jsonl!(reviewed_path, rows)

    sft_rows = [
      %{
        "id" => "row_pass",
        "prompt" => "Prompt A",
        "completion" => "Old A.",
        "text" => "Prompt A\nOld A.",
        "metadata" => %{}
      },
      %{
        "id" => "row_fail_over",
        "prompt" => "Prompt B",
        "completion" => "Old B.",
        "text" => "Prompt B\nOld B.",
        "metadata" => %{}
      },
      %{
        "id" => "row_fail_tone",
        "prompt" => "Prompt C",
        "completion" => "Old C.",
        "text" => "Prompt C\nOld C.",
        "metadata" => %{}
      }
    ]

    write_jsonl!(sft_path, sft_rows)

    capture_io(fn ->
      Mix.Task.rerun(@task, [
        "--reviewed",
        reviewed_path,
        "--sft",
        sft_path,
        "--out",
        out_path,
        "--include-ratings",
        "fail",
        "--include-tags",
        "over_disclosure"
      ])
    end)

    sft_rows = read_jsonl!(out_path)

    assert length(sft_rows) == 1
    assert hd(sft_rows)["id"] == "review_reinforcement_row_fail_over"
    assert hd(sft_rows)["completion"] == "B."
  end

  test "raises when required options are missing" do
    assert_raise Mix.Error, ~r/Missing required option: --reviewed/, fn ->
      Mix.Task.rerun(@task, ["--sft", "tmp/sft.jsonl", "--out", "tmp/out.jsonl"])
    end

    assert_raise Mix.Error, ~r/Missing required option: --sft/, fn ->
      Mix.Task.rerun(@task, ["--reviewed", "tmp/in.jsonl", "--out", "tmp/out.jsonl"])
    end

    assert_raise Mix.Error, ~r/Missing required option: --out/, fn ->
      Mix.Task.rerun(@task, ["--reviewed", "tmp/in.jsonl", "--sft", "tmp/sft.jsonl"])
    end
  end

  defp write_jsonl!(path, rows) do
    contents =
      rows
      |> Enum.map(&Jason.encode!/1)
      |> Enum.join("\n")

    File.write!(path, contents <> "\n")
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
