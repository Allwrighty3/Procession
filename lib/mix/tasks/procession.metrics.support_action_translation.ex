defmodule Mix.Tasks.Procession.Metrics.SupportActionTranslation do
  use Mix.Task

  alias Procession.Simulation.SupportActionTranslationExperiment, as: Experiment

  @shortdoc "Runs Iteration 003 support-to-action diagnostics"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {parsed, _rest, invalid} =
      OptionParser.parse(args,
        strict: [
          samples: :integer,
          first_seed: :integer,
          pre_ticks: :integer,
          post_ticks: :integer,
          restoration_ticks: :integer,
          window_ticks: :integer,
          probe_samples: :integer,
          interior_source: :integer,
          world_max: :integer,
          output: :string,
          summary_output: :string
        ]
      )

    if invalid != [], do: Mix.raise("invalid options: #{inspect(invalid)}")

    numeric = Keyword.take(parsed, Keyword.keys(Experiment.defaults()))

    options =
      case Experiment.validate_options(numeric) do
        {:ok, value} -> value
        {:error, message} -> Mix.raise(message)
      end

    output = Keyword.get(parsed, :output, "support-action-translation.jsonl")
    summary_output = Keyword.get(parsed, :summary_output, "support-action-translation-summary.txt")
    ensure_parent!(output)
    ensure_parent!(summary_output)

    result = Experiment.run(options)
    commit_sha = commit_sha()

    rows =
      Enum.map(result.transfer_rows, &Map.put(&1, :commit_sha, commit_sha)) ++
        Enum.map(result.scenario_rows, &Map.put(&1, :commit_sha, commit_sha))

    raw = Enum.map_join(rows, "\n", &Jason.encode!/1) <> "\n"
    summary = render_summary(result.summary, options, commit_sha)
    write!(output, raw)
    write!(summary_output, summary)
    Mix.shell().info(summary)
  end

  defp render_summary(summary, options, commit_sha) do
    transfer_lines =
      for id <- ["C0", "V1", "V2", "V3"] do
        item = Map.fetch!(summary.transfer, id)

        "#{id}: support_exit_rank=#{fmt(item.support_exit_rank_agreement_rate)} " <>
          "exit_sample_rank=#{fmt(item.exit_sample_rank_agreement_rate)} " <>
          "saturated=#{fmt(item.saturated_rate)} " <>
          "net_weakening_median=#{fmt(item.median_net_retained_weakening)}"
      end

    scenario_lines =
      for id <- ["S0", "S1"] do
        item = Map.fetch!(summary.scenarios, id)

        "#{id}: intake_median=#{fmt(item.cumulative_intake_median)} " <>
          "access_median=#{fmt(item.local_access_median)} " <>
          "contact_median=#{fmt(item.source_contact_rate_median)} " <>
          "improvement_median=#{fmt(item.improvement_in_access_rate_median)} " <>
          "expression_median=#{fmt(item.expression_rate_median)} corrected=#{item.corrected}"
      end

    Enum.join(
      [
        "Iteration 003 support-to-action translation",
        "experiment_id=#{Experiment.experiment_id()} commit_sha=#{commit_sha || "unavailable"}",
        "options=#{Jason.encode!(Map.new(options))}"
      ] ++ transfer_lines ++ scenario_lines ++
        ["interpretation=diagnostic only; no learner mechanism or architecture is promoted"],
      "\n"
    ) <> "\n"
  end

  defp ensure_parent!(path) do
    case File.mkdir_p(Path.dirname(path)) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("could not create output directory: #{:file.format_error(reason)}")
    end
  end

  defp write!(path, contents) do
    case File.write(path, contents) do
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

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
