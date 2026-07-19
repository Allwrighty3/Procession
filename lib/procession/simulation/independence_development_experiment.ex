defmodule Procession.Simulation.IndependenceDevelopmentExperiment do
  @moduledoc """
  Tests independence under consequence-only, demonstrative, and contingent
  task-local teaching.

  Phase one rewards :move_to_resource. Phase two invalidates that solution and
  rewards :manipulate_resource. Matched blind runs omit learned motor influence.
  """

  alias Procession.Simulation.DevelopmentalField
  alias Procession.Simulation.TaskLocalTeachingController

  @conditions [:consequence_only, :showing, :contingent]
  @actions [:signal, :move_to_resource, :manipulate_resource, :wait]
  @window 250

  @field_opts [
    micro_nodes: 64,
    input_width: 3,
    consolidation_threshold: 4,
    coherence_threshold: 0.06,
    reuse_threshold: 0.50,
    edge_retention: 0.9995,
    activity_retention: 0.72,
    plasticity_fanout: 6,
    plasticity_budget: 0.08,
    minimum_compression_gain: 2.0
  ]

  def run(opts \\ []) do
    population = Keyword.get(opts, :population, 8)
    phase_ticks = Keyword.get(opts, :phase_ticks, 1_000)
    seed = Keyword.get(opts, :seed, 1)

    conditions =
      Map.new(@conditions, fn condition ->
        learned = population(condition, population, phase_ticks, seed, true)
        blind = population(condition, population, phase_ticks, seed, false)

        {condition,
         %{
           learned: summarize(learned),
           blind: summarize(blind),
           delta: delta(learned, blind)
         }}
      end)

    clones =
      Enum.map(1..2, fn _ ->
        run_entity(:contingent, phase_ticks, seed, 0, true, true)
      end)

    %{
      population: population,
      phase_ticks: phase_ticks,
      conditions: conditions,
      clone_control: clone_summary(clones)
    }
  end

  def report(result) do
    header = [
      "Independence development with bounded teaching",
      "population=#{result.population} phase_ticks=#{result.phase_ticks} window=#{@window}",
      "clone_control: exact=#{fmt(result.clone_control.exact)} nodes=#{fmt(result.clone_control.nodes)}"
    ]

    lines =
      Enum.flat_map(@conditions, fn condition ->
        condition_result = Map.fetch!(result.conditions, condition)

        [
          summary_line(condition, :learned, condition_result.learned),
          summary_line(condition, :blind, condition_result.blind),
          delta_line(condition, condition_result.delta)
        ]
      end)

    Enum.join(header ++ lines, "\n")
  end

  defp population(condition, count, phase_ticks, seed, learned?) do
    Enum.map(1..count, fn entity ->
      run_entity(condition, phase_ticks, seed, entity, false, learned?)
    end)
  end

  defp run_entity(condition, phase_ticks, seed, entity, clone?, learned?) do
    salt = if clone?, do: :independence_clone, else: {:independence_child, entity}
    rng_seed = if clone?, do: seed, else: seed + entity * 137
    field_opts = Keyword.put(@field_opts, :encoding_salt, salt)

    initial = %{
      field: DevelopmentalField.new(field_opts),
      teacher: TaskLocalTeachingController.new(condition),
      arousal: 0.20,
      disturbance_age: 0,
      active_problem?: false,
      attempts: 0,
      records: []
    }

    phase_one =
      run_phase(
        initial,
        1,
        phase_ticks,
        condition,
        :move_to_resource,
        rng_seed,
        field_opts,
        learned?
      )

    phase_two =
      run_phase(
        phase_one,
        phase_ticks + 1,
        phase_ticks,
        condition,
        :manipulate_resource,
        rng_seed,
        field_opts,
        learned?
      )

    %{
      windows: summarize_windows(phase_two.records, phase_ticks),
      field: phase_two.field,
      fingerprint: fingerprint(phase_two.field)
    }
  end

  defp run_phase(state, start_tick, phase_ticks, condition, effective_action, seed, field_opts, learned?) do
    Enum.reduce(start_tick..(start_tick + phase_ticks - 1), state, fn tick, acc ->
      advance(acc, tick, condition, effective_action, seed, field_opts, learned?)
    end)
  end

  defp advance(state, tick, condition, effective_action, seed, field_opts, learned?) do
    state = maybe_start_problem(state, tick, seed)
    action = choose_action(state, tick, seed, field_opts, effective_action, learned?)
    self_resolved? = state.active_problem? and action == effective_action

    observation = TaskLocalTeachingController.observe(state, action, effective_action)
    teacher_action = TaskLocalTeachingController.choose(condition, observation, state.teacher)
    teacher = TaskLocalTeachingController.transition(state.teacher, observation, teacher_action)

    caregiver_resolved? =
      state.active_problem? and teacher_action in [:assist, :resolve] and not self_resolved?

    resolved? = self_resolved? or caregiver_resolved?

    arousal =
      cond do
        resolved? -> max(state.arousal - 0.35, 0.05)
        state.active_problem? -> min(state.arousal + 0.035, 1.0)
        true -> max(state.arousal - 0.01, 0.05)
      end

    features = [
      {:body_channel, :arousal, bucket(arousal)},
      {:change_channel, :arousal, trend(arousal - state.arousal)},
      {:problem_channel, state.active_problem?},
      {:problem_age, age_bucket(state.disturbance_age)},
      {:motor_channel, action},
      {:self_resolution_channel, self_resolved?},
      {:caregiver_intervention_channel, caregiver_resolved?},
      {:teaching_action_channel, teacher_action},
      {:teaching_cue_channel, teacher.cue},
      {:effective_action_channel, effective_action}
    ]

    field = DevelopmentalField.step(state.field, {:features, features}, field_opts)

    record = %{
      tick: tick,
      action: action,
      teacher_action: teacher_action,
      assistance_level: teacher.assistance_level,
      problem?: state.active_problem?,
      self_resolved?: self_resolved?,
      caregiver?: caregiver_resolved?,
      resolved?: resolved?,
      arousal: arousal,
      age: state.disturbance_age
    }

    %{
      state
      | field: field,
        teacher: teacher,
        arousal: arousal,
        active_problem?: state.active_problem? and not resolved?,
        disturbance_age:
          if(resolved?, do: 0, else: state.disturbance_age + bool_count(state.active_problem?)),
        attempts: if(resolved?, do: 0, else: state.attempts + bool_count(state.active_problem?)),
        records: [record | state.records]
    }
  end

  defp maybe_start_problem(%{active_problem?: true} = state, _tick, _seed), do: state

  defp maybe_start_problem(state, tick, seed) do
    if rem(tick + :erlang.phash2({seed, :problem_offset}, 17), 40) == 0 do
      %{
        state
        | active_problem?: true,
          disturbance_age: 0,
          attempts: 0,
          arousal: max(state.arousal, 0.38)
      }
    else
      state
    end
  end

  defp choose_action(state, tick, seed, field_opts, effective_action, learned?) do
    scores =
      Map.new(@actions, fn action ->
        exploration = :erlang.phash2({seed, tick, action}, 1000) / 1000
        urgency = urgency_score(action, state)
        cue = teaching_cue_score(action, effective_action, state.teacher.cue)
        learned = if learned?, do: learned_motor_score(state.field, action, field_opts), else: 0.0
        {action, exploration * 0.35 + urgency + cue + learned * 1.25}
      end)

    scores
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp urgency_score(:signal, state),
    do: if(state.active_problem?, do: state.arousal * 0.55, else: 0.0)

  defp urgency_score(:wait, state),
    do: if(state.active_problem?, do: 0.02, else: 0.35)

  defp urgency_score(_action, state),
    do: if(state.active_problem?, do: 0.20 + state.arousal * 0.15, else: 0.0)

  defp teaching_cue_score(action, effective_action, :weak),
    do: if(action == effective_action, do: 0.18, else: 0.0)

  defp teaching_cue_score(action, effective_action, :strong),
    do: if(action == effective_action, do: 0.38, else: 0.0)

  defp teaching_cue_score(_action, _effective_action, :none), do: 0.0

  defp learned_motor_score(field, action, field_opts) do
    targets = DevelopmentalField.active_micro_nodes(field, {:motor_channel, action}, field_opts)

    Enum.reduce(field.activity, 0.0, fn {source, activity}, total ->
      if activity >= 0.18 do
        total +
          Enum.reduce(targets, 0.0, fn target, acc ->
            acc + Map.get(field.edges, {source, target}, 0.0) * activity
          end)
      else
        total
      end
    end)
  end

  defp summarize(runs) do
    %{
      nodes: stats(Enum.map(runs, fn run -> MapSet.size(run.field.generated) end)),
      profile_similarity: profile_similarity(runs),
      windows: summarize_population_windows(runs)
    }
  end

  defp summarize_population_windows(runs) do
    runs
    |> hd()
    |> Map.fetch!(:windows)
    |> Map.keys()
    |> Enum.sort()
    |> Map.new(fn key ->
      values = Enum.map(runs, fn run -> Map.fetch!(run.windows, key) end)
      {key, merge_window_stats(values)}
    end)
  end

  defp summarize_windows(records, phase_ticks) do
    records
    |> Enum.reverse()
    |> Enum.group_by(fn record ->
      phase = if record.tick <= phase_ticks, do: 1, else: 2
      local = rem(record.tick - 1, phase_ticks)
      {phase, div(local, @window) + 1}
    end)
    |> Map.new(fn {key, values} -> {key, window_metrics(values)} end)
  end

  defp window_metrics(records) do
    problems = Enum.count(records, fn record -> record.problem? end)
    resolutions = Enum.count(records, fn record -> record.resolved? end)
    self = Enum.count(records, fn record -> record.self_resolved? end)
    caregiver = Enum.count(records, fn record -> record.caregiver? end)
    signals = Enum.count(records, fn record -> record.action == :signal end)
    demonstrations = Enum.count(records, fn record -> record.teacher_action == :demonstrate end)
    highlights = Enum.count(records, fn record -> record.teacher_action == :highlight end)

    %{
      self_resolution_rate: ratio(self, max(resolutions, 1)),
      caregiver_rate: ratio(caregiver, max(resolutions, 1)),
      signal_rate: ratio(signals, length(records)),
      unresolved_rate: ratio(problems - resolutions, max(problems, 1)),
      demonstration_rate: ratio(demonstrations, length(records)),
      highlight_rate: ratio(highlights, length(records)),
      mean_assistance_level: mean(Enum.map(records, fn record -> record.assistance_level end)),
      mean_arousal: mean(Enum.map(records, fn record -> record.arousal end)),
      mean_resolution_age:
        mean(
          Enum.map(
            Enum.filter(records, fn record -> record.resolved? end),
            fn record -> record.age end
          )
        )
    }
  end

  defp merge_window_stats(values) do
    Map.new(Map.keys(hd(values)), fn key ->
      {key, stats(Enum.map(values, fn value -> Map.fetch!(value, key) end))}
    end)
  end

  defp delta(learned_runs, blind_runs) do
    paired = Enum.zip(learned_runs, blind_runs)
    keys = learned_runs |> hd() |> Map.fetch!(:windows) |> Map.keys()

    Map.new(keys, fn key ->
      differences =
        Enum.map(paired, fn {learned, blind} ->
          learned_window = Map.fetch!(learned.windows, key)
          blind_window = Map.fetch!(blind.windows, key)

          Map.new(Map.keys(learned_window), fn metric ->
            {metric, Map.fetch!(learned_window, metric) - Map.fetch!(blind_window, metric)}
          end)
        end)

      {key, merge_window_stats(differences)}
    end)
  end

  defp clone_summary([left, right]) do
    %{
      exact: if(left.fingerprint == right.fingerprint, do: 1.0, else: 0.0),
      nodes: MapSet.size(left.field.generated)
    }
  end

  defp fingerprint(field), do: {field.nodes, field.edges, field.generated, field.recurrence}

  defp profile_similarity(runs) do
    counts = Enum.map(runs, fn run -> MapSet.size(run.field.generated) end)

    if Enum.max(counts) == 0,
      do: 1.0,
      else: 1.0 - (Enum.max(counts) - Enum.min(counts)) / Enum.max(counts)
  end

  defp stats(values) do
    sorted = Enum.sort(values)
    avg = mean(values)
    variance = mean(Enum.map(values, fn value -> :math.pow(value - avg, 2) end))

    %{
      mean: avg,
      median: median(sorted),
      min: hd(sorted),
      max: List.last(sorted),
      sd: :math.sqrt(variance)
    }
  end

  defp median(values) do
    count = length(values)
    middle = div(count, 2)

    if rem(count, 2) == 1,
      do: Enum.at(values, middle),
      else: (Enum.at(values, middle - 1) + Enum.at(values, middle)) / 2
  end

  defp summary_line(condition, mode, summary) do
    final = Map.fetch!(summary.windows, {2, 4})

    "#{condition}_#{mode}: nodes=#{stats_text(summary.nodes)} profile=#{fmt(summary.profile_similarity)} " <>
      "final_self=#{stats_text(final.self_resolution_rate)} " <>
      "final_caregiver=#{stats_text(final.caregiver_rate)} " <>
      "final_signal=#{stats_text(final.signal_rate)} " <>
      "final_unresolved=#{stats_text(final.unresolved_rate)} " <>
      "final_demo=#{stats_text(final.demonstration_rate)} " <>
      "final_highlight=#{stats_text(final.highlight_rate)} " <>
      "final_assist_level=#{stats_text(final.mean_assistance_level)}"
  end

  defp delta_line(condition, windows) do
    window_text =
      Enum.map_join(Enum.sort(Map.keys(windows)), " ", fn key ->
        window = Map.fetch!(windows, key)

        "#{inspect(key)}:self=#{fmt(window.self_resolution_rate.mean)}," <>
          "care=#{fmt(window.caregiver_rate.mean)}," <>
          "signal=#{fmt(window.signal_rate.mean)}"
      end)

    "#{condition}_learned_minus_blind: #{window_text}"
  end

  defp stats_text(stats),
    do: "#{fmt(stats.mean)}[#{fmt(stats.min)}..#{fmt(stats.max)}]sd=#{fmt(stats.sd)}"

  defp bucket(value), do: value |> Kernel.*(4) |> round() |> min(4) |> max(0)
  defp age_bucket(age), do: min(div(age, 2), 4)
  defp trend(delta) when delta > 0.015, do: :rising
  defp trend(delta) when delta < -0.015, do: :falling
  defp trend(_), do: :stable
  defp bool_count(true), do: 1
  defp bool_count(false), do: 0
  defp ratio(_num, 0), do: 0.0
  defp ratio(num, den), do: num / den
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
