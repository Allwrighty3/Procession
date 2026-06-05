defmodule Mix.Tasks.Procession.Training.ReviewSummaryTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Procession.Training.ReviewSummary

  test "summarizes ratings and error tags from review JSONL" do
    path = "tmp/training_reviews/review_summary_test.jsonl"

    File.mkdir_p!(Path.dirname(path))

    contents =
      [
        %{
          "id" => "row_1",
          "rating" => "fail",
          "error_tags" => ["over_disclosure", "catchphrase_tail"]
        },
        %{
          "id" => "row_2",
          "rating" => "minor",
          "error_tags" => ["over_disclosure", "awkward_but_safe"]
        },
        %{
          "id" => "row_3",
          "rating" => "fail",
          "error_tags" => ["followup_not_allowed"]
        }
      ]
      |> Enum.map(&Jason.encode!/1)
      |> Enum.join("\n")

    File.write!(path, contents <> "\n")

    output =
      capture_io(fn ->
        ReviewSummary.run([path])
      end)

    assert output =~ "Rows: 3"
    assert output =~ "fail: 2"
    assert output =~ "minor: 1"
    assert output =~ "over_disclosure: 2"
    assert output =~ "catchphrase_tail: 1"
    assert output =~ "followup_not_allowed: 1"
    assert output =~ "awkward_but_safe: 1"

    File.rm!(path)
  end

  test "raises when no path is provided" do
    assert_raise Mix.Error, ~r/Expected review JSONL path/, fn ->
      ReviewSummary.run([])
    end
  end
end
