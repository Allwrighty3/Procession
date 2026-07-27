defmodule Procession.Simulation.LocalInterpersonalInfluenceExperiment do
  @moduledoc """
  Demonstrates low-level interpersonal influence without named social conclusions.

  A nearby body is perceived through grounded relative position. Repeated locally observable
  motor events build directed relational history and feed social expectation/surprise signals
  into the observer's developmental sensorimotor loop. The experiment reports resulting motor
  support; it does not assign following, avoidance, friendship, teaching, or authority labels.
  """

  alias Procession.Simulation.CausalWorldKernel
  alias Procession.Simulation.DevelopmentalSensorimotorLoop
  alias Procession.Simulation.SocialRelationPlane

  @default_cycles 96
  @default_seed 71

  def run(opts \\ []) do
    cycles = positive(Keyword.get(opts, :cycles, @default_cycles), @default_cycles)
    seed = Keyword.get(opts, :seed, @default_seed)
    actor_id = "local_actor"
    observer_id = "local_observer"

    world =
      CausalWorldKernel.new(
        bounds: {4, 4},
        perception_radius: 2,
        entities: [
          %{id: actor_id, position: {2, 1}, energy: 0.8},
          %{id: observer_id, position: {1, 1}, energy: 0.8}
        ],
        resources: []
      )

    presence_features = CausalWorldKernel.perceive(world, observer_id)
    event = observed_event(actor_id)
    raw_signal = SocialRelationPlane.physical_observation_signal(event)

    initial_loop =
      DevelopmentalSensorimotorLoop.new(
        field_opts: [
          micro_nodes: 96,
          input_width: 4,
          encoding_salt: {:local_interpersonal_influence, seed},
          output_source_threshold: 0.0,
          output_edge_retention: 1.0,
          output_plasticity_budget: 0.5
        ],
        body_opts: [initial_coordination: 1.0],
        position: {1, 1}
      )

    {_baseline_loop, baseline_outcome} =
      initial_loop
      |> DevelopmentalSensorimotorLoop.sense(presence_features)
      |> DevelopmentalSensorimotorLoop.emit(1,
        seed: seed,
        bounds: {4, 4},
        output_exploration: 0.0
      )

    {plane, trained_loop, target_pattern} =
      Enum.reduce(1..cycles, {SocialRelationPlane.new(), initial_loop, nil}, fn cycle,
                                                                              {plane, loop,
                                                                               target} ->
        {plane, social_signals} =
          SocialRelationPlane.observe(plane, observer_id, event, cycle,
            observer_salience: 1.0
          )

        sensed =
          DevelopmentalSensorimotorLoop.sense(
            loop,
            presence_features ++ [raw_signal] ++ social_signals
          )

        {emitted, outcome} =
          DevelopmentalSensorimotorLoop.emit(sensed, cycle,
            seed: seed,
            bounds: {4, 4},
            output_exploration: 1.0
          )

        target = target || outcome.pattern
        coherence = if outcome.pattern == target, do: 1.0, else: -0.35

        closed =
          DevelopmentalSensorimotorLoop.feedback(
            emitted,
            [
              {:signal, {:observed_actor_consequence, event_signature(event)}, 1.0},
              {:signal, {:observer_motor_match, outcome.pattern == target}, 1.0}
            ],
            coherence
          )

        {plane, closed, target}
      end)

    influenced =
      trained_loop
      |> DevelopmentalSensorimotorLoop.sense(
        presence_features ++ [raw_signal] ++ social_signals(plane, observer_id, event, cycles + 1)
      )

    {_influenced_loop, influenced_outcome} =
      DevelopmentalSensorimotorLoop.emit(influenced, cycles + 1,
        seed: seed,
        bounds: {4, 4},
        output_exploration: 0.0
      )

    relation =
      SocialRelationPlane.relation(
        plane,
        observer_id,
        actor_id,
        SocialRelationPlane.event_context(event)
      )

    trace = DevelopmentalSensorimotorLoop.trace(trained_loop)

    %{
      experiment: :local_interpersonal_influence,
      cycles: cycles,
      actor_id: actor_id,
      observer_id: observer_id,
      grounded_presence:
        Enum.filter(presence_features, fn
          {:signal, {:nearby_body, ^actor_id, _direction, _band}, _magnitude} -> true
          _ -> false
        end),
      observed_event_signature: event_signature(event),
      relation: relation,
      social_relation_count: SocialRelationPlane.trace(plane).relation_count,
      target_motor_pattern: target_pattern,
      baseline_motor_pattern: baseline_outcome.pattern,
      influenced_motor_pattern: influenced_outcome.pattern,
      motor_pattern_changed?: baseline_outcome.pattern != influenced_outcome.pattern,
      learned_output_edges: trace.learned_output_edges,
      active_sensory_nodes: trace.active_sensory_nodes,
      named_social_conclusions_present?: named_social_conclusions?(plane)
    }
  end

  defp social_signals(plane, observer_id, event, tick) do
    {_updated, signals} =
      SocialRelationPlane.observe(plane, observer_id, event, tick, observer_salience: 1.0)

    signals
  end

  defp observed_event(actor_id) do
    %{
      tick: 1,
      entity_id: actor_id,
      motor_pattern: {:motor_a, :motor_b},
      from: {2, 1},
      proposed: {3, 1},
      position: {3, 1},
      displaced?: true,
      blocked?: false,
      transferred: 0.0
    }
  end

  defp event_signature(event), do: SocialRelationPlane.event_signature(event)

  defp named_social_conclusions?(plane) do
    plane
    |> SocialRelationPlane.trace()
    |> inspect()
    |> String.match?(~r/\b(friend|trust|teacher|leader|help|avoid|follow|authority)\b/i)
  end

  defp positive(value, _fallback) when is_integer(value) and value > 0, do: value
  defp positive(_value, fallback), do: fallback
end