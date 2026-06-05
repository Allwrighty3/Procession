defmodule Mix.Tasks.Procession.Training.ReviewQueueTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Procession.Training.ReviewQueue

  test "extracts non-pass rows into pretty JSON queue" do
    source_path = "tmp/training_reviews/review_queue_source.jsonl"
    out_path = "tmp/training_reviews/review_queue_output.json"

    File.mkdir_p!(Path.dirname(out_path))

    rows = [
      %{
        "id" => "row_pass",
        "expected" => "Corvin.",
        "raw_generated" => "Corvin.",
        "rating" => "pass",
        "error_tags" => [],
        "auto_review_notes" => [],
        "training_note" => ""
      },
      %{
        "id" => "row_fail",
        "expected" => "Corvin.",
        "raw_generated" => "Corvin. I map roads.",
        "rating" => "fail",
        "error_tags" => ["over_disclosure"],
        "auto_review_notes" => ["Raw output provides more detail than expected."],
        "training_note" => "name_only should stay minimal."
      }
    ]

    write_jsonl!(source_path, rows)

    output =
      capture_io(fn ->
        ReviewQueue.run([
          "--source",
          source_path,
          "--out",
          out_path
        ])
      end)

    assert output =~ "Wrote 1 review queue rows"

    queue =
      out_path
      |> File.read!()
      |> Jason.decode!()

    assert queue["source_file"] == source_path
    assert queue["row_count"] == 1
    assert queue["instructions"]["edit_fields"] == ["rating", "error_tags", "training_note"]

    assert [row] = queue["rows"]
    assert row["id"] == "row_fail"
    assert row["expected"] == "Corvin."
    assert row["raw_generated"] == "Corvin. I map roads."
    assert row["rating"] == "fail"
    assert row["error_tags"] == ["over_disclosure"]
    assert row["auto_review_notes"] == ["Raw output provides more detail than expected."]
    assert row["training_note"] == "name_only should stay minimal."

    File.rm_rf!("tmp/training_reviews")
  end

  test "can include pass rows when requested" do
    source_path = "tmp/training_reviews/review_queue_include_pass_source.jsonl"
    out_path = "tmp/training_reviews/review_queue_include_pass_output.json"

    File.mkdir_p!(Path.dirname(out_path))

    rows = [
      %{"id" => "row_pass", "rating" => "pass"},
      %{"id" => "row_minor", "rating" => "minor"}
    ]

    write_jsonl!(source_path, rows)

    ReviewQueue.run([
      "--source",
      source_path,
      "--out",
      out_path,
      "--include-pass"
    ])

    queue =
      out_path
      |> File.read!()
      |> Jason.decode!()

    assert queue["row_count"] == 2
    assert Enum.map(queue["rows"], & &1["id"]) == ["row_pass", "row_minor"]

    File.rm_rf!("tmp/training_reviews")
  end

  test "raises when required options are missing" do
    assert_raise Mix.Error, ~r/Missing required option/, fn ->
      ReviewQueue.run([])
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
