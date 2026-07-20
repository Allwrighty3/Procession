defmodule Mix.Tasks.Procession.Metrics.RevisionOpportunityAttribution do
  use Mix.Task

  alias Procession.Simulation.RevisionOpportunityAttributionFactorialExperiment, as: Experiment

  @shortdoc "Runs revision-opportunity and attribution factorial metrics"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    {parsed, _rest, invalid} = OptionParser.parse(args, strict: [samples: :integer, first_seed: :integer,
      control_pre_ticks: :integer, control_post_ticks: :integer, extended_post_ticks: :integer,
      extended_pre_ticks: :integer, window_ticks: :integer, output: :string, summary_output: :string])
    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    numeric = Keyword.take(parsed, Keyword.keys(Experiment.defaults()))
    {:ok, options} = case Experiment.validate_options(numeric) do
      {:ok, value} -> {:ok, value}
      {:error, message} -> Mix.raise(message)
    end
    output = Keyword.get(parsed, :output, "revision-opportunity-attribution.jsonl")
    summary_output = Keyword.get(parsed, :summary_output, "revision-opportunity-attribution-summary.txt")
    ensure_parent!(output)
    ensure_parent!(summary_output)
    result = Experiment.run(options)
    commit_sha = commit_sha()
    metadata = %{schema_version: Experiment.schema_version(), experiment_id: Experiment.experiment_id(),
      commit_sha: commit_sha, options: Map.new(options), environment: %{elixir: System.version(), otp: to_string(:erlang.system_info(:otp_release))}}
    raw = Enum.map_join(result.rows, "\n", &(Jason.encode!(Map.put(&1, :commit_sha, commit_sha))) <> "\n"
    summary = summary(result.summary, metadata)
    write!(output, raw)
    write!(summary_output, summary)
    Mix.shell().info(summary)
  end

  defp write!(path, contents) do
    with :ok <- File.write(path, contents) do :ok
    else {:error, reason} -> Mix.raise("could not write #{path}: #{:file.format_error(reason)}") end
  end
  defp ensure_parent!(path) do
    case File.mkdir_p(Path.dirname(path)) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("could not write #{path}: #{:file.format_error(reason)}")
    end
  end
  defp commit_sha do
    case System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _ -> nil
    end
  end
  defp summary(result, metadata) do
    lines = [
      "Revision opportunity and attribution factorial",
      "experiment_id=#{metadata.experiment_id} commit_sha=#{metadata.commit_sha || \"unavailable\"}",
      "options=#{Jason.encode!(metadata.options)}",
      "environment=elixir=#{metadata.environment.elixir} otp=#{metadata.environment.otp}",
      "behavioral_correction_delay=post-reversal ending tick of the first qualifying sliding window"
    ]

    variant_lines =
      for id <- ["C0", "V1", "V2", "V3"] do
        summary = result.variants[id]
        behavioral = summary.behavioral_corrected
        disagreement = summary.metric_disagreement
        "#{id}: behavioral_corrected=#{behavioral.count}/#{behavioral.denominator} (#{format(behavioral.rate)}) " <>
          "behavioral_delay_median=#{format(summary.behavioral_delay.median)} iqr=#{format_iqr(summary.behavioral_delay.iqr)} " <>
          "obsolete_median=#{format(summary.obsolete_action_rate.median)} iqr=#{format_iqr(summary.obsolete_action_rate.iqr)} " <>
          "metric_disagreement=#{disagreement.count}/#{disagreement.denominator} (#{format(disagreement.rate)})"
      end

    paired_lines =
      for id <- ["C0_to_V1", "V1_to_V2", "V1_to_V3"] do
        delta = result.paired_deltas[id]
        behavioral = delta.behavioral_correction
        obsolete = delta.normalized_obsolete_action_rate
        "#{id}.behavioral_correction: improved=#{behavioral.improved}/#{behavioral.denominator} tied=#{behavioral.tied}/#{behavioral.denominator} worsened=#{behavioral.worsened}/#{behavioral.denominator}\n" <>
          "#{id}.normalized_obsolete_action_rate: improved=#{obsolete.improved}/#{obsolete.denominator} tied=#{obsolete.tied}/#{obsolete.denominator} worsened=#{obsolete.worsened}/#{obsolete.denominator}"
      end

    criteria_lines =
      Enum.map([:success, :failure, :attribution_dominance, :measurement_disagreement, :inconclusive], fn name ->
        definition = Map.fetch!(result.criteria.definitions, name)
        "criterion.#{name}=#{definition}; met=#{Map.fetch!(result.criteria, name)}"
      end)

    Enum.join(lines ++ variant_lines ++ paired_lines ++ criteria_lines ++ [
      "interpretation=Observer-only measurements; no architectural promotion is implied."
    ], "\n") <> "\n"
  end

  defp format(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
  defp format_iqr([low, high]), do: "[#{format(low)},#{format(high)}]"
end
