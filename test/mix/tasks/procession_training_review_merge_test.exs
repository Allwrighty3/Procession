defmodule Mix.Tasks.Procession.Training.ReviewMergeTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Procession.Training.ReviewMerge

  test "merges reviewed queue fields back into full source rows" do
    source_path = "tmp/training_reviews/review_merge_source.jsonl"
    reviewed_path = "tmp/training_reviews/review_merge_queue.json"
    out_path = "tmp/training_reviews/review_merge_output.jsonl"

    File.mkdir_p!(Path.dirname(out_path))

    source_rows = [
      %{
        "id" => "row_1",
        "expected" => "Corvin.",
        "raw_generated" => "Corvin. I map roads.",
        "rating" => "fail",
        "error_tags" => ["over_disclosure"],
        "confidence" => "medium",
        "metadata" => %{"category" => "npc_interaction_test"},
        "training_note" => "old note"
      },
      %{
        "id" => "row_2",
        "expected" => "Nella.",
        "raw_generated" => "Nella.",
        "rating" => "pass",
        "error_tags" => [],
        "confidence" => "high",
        "metadata" => %{"category" => "npc_interaction_test"},
        "training_note" => ""
      }
    ]

    reviewed = %{
      "source_file" => source_path,
      "row_count" => 1,
      "rows" => [
        %{
          "id" => "row_1",
          "rating" => "minor",
          "error_tags" => ["awkward_but_safe"],
          "training_note" => "Reviewed manually."
        }
      ]
    }

    write_jsonl!(source_path, source_rows)
    File.write!(reviewed_path, Jason.encode!(reviewed, pretty: true) <> "\n")

    output =
      capture_io(fn ->
        ReviewMerge.run([
          "--source",
          source_path,
          "--reviewed",
          reviewed_path,
          "--out",
          out_path
        ])
      end)

    assert output =~ "Merged 1 reviewed rows"
    assert output =~ "Total rows: 2"

    [merged_1, merged_2] = read_jsonl!(out_path)

    assert merged_1["id"] == "row_1"
    assert merged_1["rating"] == "minor"
    assert merged_1["error_tags"] == ["awkward_but_safe"]
    assert merged_1["training_note"] == "Reviewed manually."
    assert merged_1["human_reviewed"] == true

    assert merged_1["expected"] == "Corvin."
    assert merged_1["raw_generated"] == "Corvin. I map roads."
    assert merged_1["confidence"] == "medium"
    assert merged_1["metadata"] == %{"category" => "npc_interaction_test"}

    assert merged_2["id"] == "row_2"
    assert merged_2["rating"] == "pass"
    refute Map.has_key?(merged_2, "human_reviewed")

    File.rm_rf!("tmp/training_reviews")
  end

  test "raises when reviewed row id is missing from source" do
    source_path = "tmp/training_reviews/review_merge_missing_source.jsonl"
    reviewed_path = "tmp/training_reviews/review_merge_missing_queue.json"
    out_path = "tmp/training_reviews/review_merge_missing_output.jsonl"

    File.mkdir_p!(Path.dirname(out_path))

    write_jsonl!(source_path, [
      %{"id" => "row_1", "rating" => "pass", "error_tags" => []}
    ])

    reviewed = %{
      "rows" => [
        %{"id" => "missing_row", "rating" => "fail", "error_tags" => []}
      ]
    }

    File.write!(reviewed_path, Jason.encode!(reviewed, pretty: true) <> "\n")

    assert_raise Mix.Error, ~r/reviewed_rows_missing_from_source/, fn ->
      ReviewMerge.run([
        "--source",
        source_path,
        "--reviewed",
        reviewed_path,
        "--out",
        out_path
      ])
    end

    File.rm_rf!("tmp/training_reviews")
  end

  test "raises when required options are missing" do
    assert_raise Mix.Error, ~r/Missing required option/, fn ->
      ReviewMerge.run([])
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
