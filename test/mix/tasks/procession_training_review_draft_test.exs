defmodule Mix.Tasks.Procession.Training.ReviewDraftTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Procession.Training.ReviewDraft

  test "creates review draft rows from SFT and raw generations" do
    sft_path = "tmp/training_reviews/review_draft_sft.jsonl"
    raw_path = "tmp/training_reviews/review_draft_raw.jsonl"
    out_path = "tmp/training_reviews/review_draft_output.jsonl"

    File.mkdir_p!(Path.dirname(out_path))

    sft_rows = [
      %{
        "id" => "row_1",
        "completion" => "Corvin.",
        "metadata" => %{
          "category" => "npc_interaction_qe7b_memory_policy_patch",
          "delivery_style" => %{"detail_level" => "minimal"},
          "conversational_move" => %{"move" => "name_only"},
          "recent_memory" => %{"reference_policy" => "do_not_reference"}
        }
      }
    ]

    raw_rows = [
      %{
        "id" => "row_1",
        "expected" => "Corvin.",
        "generated" => "Corvin. I map roads from Windmere."
      }
    ]

    write_jsonl!(sft_path, sft_rows)
    write_jsonl!(raw_path, raw_rows)

    output =
      capture_io(fn ->
        ReviewDraft.run([
          "--phase",
          "qe7c",
          "--training-run",
          "smollm2_npc_lora_qe7c_memory_expression",
          "--eval-run",
          "qe7c_exact_rows_generate",
          "--eval-set",
          "qe7c_exact_rows",
          "--sft",
          sft_path,
          "--raw",
          raw_path,
          "--out",
          out_path
        ])
      end)

    assert output =~ "Wrote 1 review draft rows"

    [review_row] =
      out_path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert review_row["phase"] == "qe7c"
    assert review_row["training_run"] == "smollm2_npc_lora_qe7c_memory_expression"
    assert review_row["eval_run"] == "qe7c_exact_rows_generate"
    assert review_row["eval_set"] == "qe7c_exact_rows"
    assert review_row["id"] == "row_1"
    assert review_row["expected"] == "Corvin."
    assert review_row["raw_generated"] == "Corvin. I map roads from Windmere."
    assert review_row["rating"] == ""
    assert review_row["error_tags"] == []
    assert review_row["training_note"] == ""
    assert review_row["metadata"]["category"] == "npc_interaction_qe7b_memory_policy_patch"
    assert review_row["metadata"]["conversational_move"] == %{"move" => "name_only"}

    File.rm_rf!("tmp/training_reviews")
  end

  test "raises when required options are missing" do
    assert_raise Mix.Error, ~r/Missing required option/, fn ->
      ReviewDraft.run([])
    end
  end

  defp write_jsonl!(path, rows) do
    contents =
      rows
      |> Enum.map(&Jason.encode!/1)
      |> Enum.join("\n")

    File.write!(path, contents <> "\n")
  end
end
