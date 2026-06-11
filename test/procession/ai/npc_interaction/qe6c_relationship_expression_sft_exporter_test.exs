defmodule Procession.AI.NPCInteraction.QE6CRelationshipExpressionSFTExporterTest do
  use ExUnit.Case, async: true

  alias Procession.AI.NPCInteraction.QE6CRelationshipExpressionSFTExporter

  test "rejects invalid output path" do
    assert QE6CRelationshipExpressionSFTExporter.export(nil) ==
             {:error, :invalid_qe6c_relationship_expression_sft_export_path}
  end

  defp read_jsonl!(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
