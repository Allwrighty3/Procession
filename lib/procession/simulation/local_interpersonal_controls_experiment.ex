defmodule Procession.Simulation.LocalInterpersonalControlsExperiment do
  @moduledoc """
  Compares grounded interpersonal learning against absence, range, behavioral variation,
  reversal, and actor-identity controls. No scenario stores named social conclusions.
  """

  alias Procession.Simulation.CausalWorldKernel
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.SocialRelationPlane

  @default_cycles 96
  @scenarios [:absent, :out_of_range, :stationary, :consistent, :random, :reversal, :new_actor]

  def run(opts \\ []) do
    cycles = positive(Keyword.get(opts, :cycles, @default_cycles), @default_cycles)
    seed = Keyword.get(opts, :seed, 41)

    results = Map.new(@scenarios, &{&1, run_scenario(&1, cycles, seed)})

    %{
      experiment: :local_interpersonal_controls,
      cycles: cycles,
      seed: seed,
      scenarios: results,
      grounded_effect_present?:
        results.consistent.relation_count > results.absent.relation_count and
          results.consistent.relation_count > results.out_of_range.relation_count,
      actor_specific?: results.new_actor.trained_actor_relation? and not results.new_actor.new_actor_relation?,
      reversal_observed?:
        results.reversal.east_relation? and results.reversal.west_relation?,
      named_social_conclusions_present?:
        Enum.any?(results, fn {_name, result} -> result.named_social_conclusions_present? end)
    }
  end

  defp run_scenario(scenario, cycles, seed) do
    observer = "control_observer"
    trained_actor = "control_actor"
    new_actor = "control_actor_new"
    presence = presence_features(scenario, observer, trained_actor)
    loop = new_loop(seed, scenario)

    {plane, loop, target} =
      Enum.reduce(1..cycles, {SocialRelationPlane.new(), loop, nil}, fn cycle, {plane, loop, target} ->
        event = cycle_event(scenario, trained_actor, cycle, cycles)

        {plane, social_signals} =
          if event do
            SocialRelationPlane.observe(plane, observer, event, cycle, observer_salience: 1.0)
          else
            {plane, []}
          end

        raw = if event, do: [SocialRelationPlane.physical_observation_signal(event)], else: []
        sensed = DevelopmentalSensorimotorLoop.sense(loop, presence ++ raw ++ social_signals)

        {emitted, outcome} =
          DevelopmentalSensorimotorLoop.emit(sensed, cycle,
            seed: seed,
            bounds: {6, 6},
            output_exploration: 1.0
          )

        target = target || outcome.pattern
        coherence = if event && outcome.pattern == target, do: 1.0, else: if(event, do: -0.35, else: 0.0)
        loop = DevelopmentalSensorimotorLoop.feedback(emitted, consequence_features(event), coherence)
        {plane, loop, target}
      end)

    probe_presence =
      if scenario == :new_actor do
        presence_features(:consistent, observer, new_actor)
      else
        presence
      end

    probe_actor = if scenario == :new_actor, do: new_actor, else: trained_actor
    probe_event = observed_event(probe_actor, :east, cycles + 1, scenario == :stationary)
    probe_signals = relation_signals(plane, observer, probe_event, cycles + 1)
    sensed = DevelopmentalSensorimotorLoop.sense(loop, probe_presence ++ probe_signals)
    {_loop, outcome} = DevelopmentalSensorimotorLoop.emit(sensed, cycles + 1, seed: seed, bounds: {6, 6}, output_exploration: 0.0)
    trace = SocialRelationPlane.trace(plane)

    %{
      relation_count: trace.relation_count,
      observations: trace.observations,
      motor_pattern: outcome.pattern,
      target_motor_pattern: target,
      trained_actor_relation?: actor_relation?(plane, observer, trained_actor),
      new_actor_relation?: actor_relation?(plane, observer, new_actor),
      east_relation?: direction_relation?(plane, observer, trained_actor, :east),
      west_relation?: direction_relation?(plane, observer, trained_actor, :west),
      grounded_presence_count: count_presence(probe_presence),
      named_social_conclusions_present?: named_social_conclusions?(plane)
    }
  end

  defp presence_features(:absent, _observer, _actor), do: []

  defp presence_features(scenario, observer, actor) do
    actor_position = if scenario == :out_of_range, do: {6, 6}, else: {2, 1}

    CausalWorldKernel.new(
      bounds: {6, 6},
      perception_radius: 2,
      entities: [
        %{id: observer, position: {1, 1}, energy: 0.8},
        %{id: actor, position: actor_position, energy: 0.8}
      ],
      resources: []
    )
    |> CausalWorldKernel.perceive(observer)
    |> Enum.filter(fn
      {:signal, {:nearby_body, ^actor, _, _}, _} -> true
      _ -> false
    end)
  end

  defp cycle_event(:absent, _actor, _cycle, _cycles), do: nil
  defp cycle_event(:out_of_range, _actor, _cycle, _cycles), do: nil
  defp cycle_event(:stationary, actor, cycle, _cycles), do: observed_event(actor, :none, cycle, true)
  defp cycle_event(:consistent, actor, cycle, _cycles), do: observed_event(actor, :east, cycle, false)
  defp cycle_event(:new_actor, actor, cycle, _cycles), do: observed_event(actor, :east, cycle, false)

  defp cycle_event(:random, actor, cycle, _cycles) do
    direction = Enum.at([:east, :north, :west, :south], rem(cycle - 1, 4))
    observed_event(actor, direction, cycle, false)
  end

  defp cycle_event(:reversal, actor, cycle, cycles) do
    observed_event(actor, if(cycle <= div(cycles, 2), do: :east, else: :west), cycle, false)
  end

  defp observed_event(actor, direction, tick, stationary?) do
    from = {2, 1}
    position = move(from, direction)

    %{
      tick: tick,
      entity_id: actor,
      motor_pattern: {:motor_a, :motor_b},
      from: from,
      proposed: position,
      position: position,
      displaced?: not stationary?,
      blocked?: false,
      transferred: 0.0
    }
  end

  defp move(position, :none), do: position
  defp move({x, y}, :east), do: {x + 1, y}
  defp move({x, y}, :west), do: {x - 1, y}
  defp move({x, y}, :north), do: {x, y - 1}
  defp move({x, y}, :south), do: {x, y + 1}

  defp consequence_features(nil), do: [{:signal, :no_local_actor_event, 0.1}]
  defp consequence_features(event), do: [{:signal, {:observed_actor_consequence, SocialRelationPlane.event_signature(event)}, 1.0}]

  defp relation_signals(plane, observer, event, tick) do
    {_plane, signals} = SocialRelationPlane.observe(plane, observer, event, tick, observer_salience: 1.0)
    signals
  end

  defp actor_relation?(plane, observer, actor) do
    plane.relations |> Map.keys() |> Enum.any?(fn {o, a, _context} -> o == observer and a == actor end)
  end

  defp direction_relation?(plane, observer, actor, direction) do
    plane.relations
    |> Map.keys()
    |> Enum.any?(fn
      {^observer, ^actor, {:movement_attempt, ^direction}} -> true
      _ -> false
    end)
  end

  defp count_presence(features), do: Enum.count(features, &match?({:signal, {:nearby_body, _, _, _}, _}, &1))

  defp named_social_conclusions?(plane) do
    plane |> SocialRelationPlane.trace() |> inspect() |> String.match?(~r/\b(friend|trust|teacher|leader|help|avoid|follow|authority)\b/i)
  end

  defp new_loop(seed, scenario) do
    DevelopmentalSensorimotorLoop.new(
      field_opts: [
        micro_nodes: 96,
        input_width: 4,
        encoding_salt: {:interpersonal_control, scenario, seed},
        output_source_threshold: 0.0,
        output_edge_retention: 1.0,
        output_plasticity_budget: 0.5
      ],
      body_opts: [initial_coordination: 1.0],
      position: {1, 1}
    )
  end

  defp positive(value, _fallback) when is_integer(value) and value > 0, do: value
  defp positive(_value, fallback), do: fallback
end
