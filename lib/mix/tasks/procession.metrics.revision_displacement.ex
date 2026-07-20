defmodule Mix.Tasks.Procession.Metrics.RevisionDisplacement do
  use Mix.Task

  alias Procession.Simulation.RevisionDisplacementFactorialExperiment, as: Experiment

  @shortdoc "Runs Iteration 002 revision displacement factorial metrics"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _rest, invalid} =
      OptionParser.parse(args,
        strict: [samples: :integer, first_seed: :integer, pre_ticks: :integer,
          post_ticks: :integer, restoration_ticks: :integer, window_ticks: :integer,
          recovery_window_ticks: :integer, competition_fraction: :float,
          output: :string, summary_output: :string]
      )

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")
    numeric = Keyword.take(parsed, Keyword.keys(Experiment.defaults()))

    options =
      case Experiment.validate_options(numeric) do
        {:ok, value} -> value
        {:error, message} -> Mix.raise(message)
      end

    output = Keyword.get(parsed, :output, "revision-displacement.jsonl")
    summary_output = Keyword.get(parsed, :summary_output, "revision-displacement-summary.txt")
    ensure_parent!(output)
    ensure_parent!(summary_output)

    result = Experiment.run(options)
    commit_sha = commit_sha()

    raw =
      Enum.map_join(result.rows, "\n", fn row ->
        Jason.encode!(Map.put(row, :commit_sha, commit_sha))
      end) <> "\n"

    summary = summary(result.summary, options, commit_sha)
    write!(output, raw)
    write!(summary_output, summary)
    Mix.shell().info(summary)
  end

  defp summary(result, options, commit_sha) do
    header = [
      "Iteration 002 revision displacement factorial",
      "experiment_id=#{Experiment.experiment_id()} commit_sha=#{commit_sha || "unavailable"}",
      "options=#{Jason.encode!(Map.new(options))}",
      "environment=elixir=#{System.version()} otp=#{:erlang.system_info(:otp_release)}"
    ]

    variants =
      for id <- ["C0", "V1", "V2", "V3"] do
        value = result.variants[id]
        corrected = value.behavioral_corrected
        "#{id}: corrected=#{corrected.count}/#{corrected.denominator} (#{fmt(corrected.rate)}) " <>
          "obsolete=#{fmt(value.obsolete_action_rate.median)} " <>
          "expression=#{fmt(value.expression_rate.median)} intake=#{fmt(value.intake.median)} " <>
          "removed=#{fmt(value.support_removed.median)} recovery=#{fmt(value.recovery_ratio.median)} " <>
          "displaced=#{fmt(value.displaced_support.median)} restoration=#{fmt(value.restoration_original_action_rate.median)}"
      end

    paired =
      for id <- ["V1", "V2", "V3"] do
        value = result.paired_deltas["C0_to_#{id}"]
        "C0_to_#{id}: improved=#{value.improved}/#{value.denominator} " <>
          "tied=#{value.tied}/#{value.denominator} worsened=#{value.worsened}/#{value.denominator}"
      end

    criteria =
      for name <- [:success, :failure, :magnitude_supported, :competition_supported,
                    :interaction_supported, :reinforcement_recovery, :inconclusive] do
        "criterion.#{name}=#{Map.fetch!(result.criteria, name)}"
      end

    Enum.join(header ++ variants ++ paired ++ criteria ++ [
      "interpretation=Observer-only evidence; no architectural promotion is implied."
    ], "\n") <> "\n"
  end

  defp write!(path, contents) do
    case File.write(path, contents) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("could not write #{path}: #{:file.format_error(reason)}")
    end
  end

  defp ensure_parent!(path) do
    case File.mkdir_p(Path.dirname(path)) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("could not create parent for #{path}: #{:file.format_error(reason)}")
    end
  end

  defp commit_sha do
    case System.cmd("git", ["rev-parse", "HEAD"], stderr_to_stdout: true) do
      {sha, 0} -> String.trim(sha)
      _ -> nil
    end
  end

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
