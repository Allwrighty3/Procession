defmodule Procession.Simulation.HomeForagingMemoryAudit do
  @moduledoc false

  alias Procession.Simulation.DevelopmentalField

  @actions [:manipulate, :wait, :north, :south, :east, :west]
  @conditions [:abrupt_assistance, :staged_assistance]
  @home {0, 0}
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
    population = Keyword.get(opts, :population, 48)
    width = Keyword.get(opts, :stage_ticks, 40)
    withdrawal = Keyword.get(opts, :withdrawal_ticks, 120)
    seed = Keyword.get(opts, :seed, 1)
    total = width * 5 + withdrawal

    rows =
      for condition <- @conditions, entity <- 1..population do
        run_one(condition, width, total, seed, entity)
      end

    %{rows: rows, summary: summarize(rows, population), examples: examples(rows)}
  end

  def report(%{summary: summary, examples: examples}) do
    lines =
      Enum.map(@conditions, fn condition ->
        s = summary[condition]

        "#{condition}: survived=#{s.survived}/#{s.population} reached=#{s.reached}/#{s.population} " <>
          "collected=#{s.collected}/#{s.population} returned_after_collect=#{s.returned}/#{s.population} " <>
          "completed=#{s.completed}/#{s.population} generated=#{fmt(s.generated)} " <>
          "generated_edges=#{fmt(s.generated_edges)} spanning_nodes=#{fmt(s.spanning_nodes)} " <>
          "active_generated=#{fmt(s.active_generated)} top_action=#{s.top_action}"
      end)

    example_lines =
      Enum.flat_map(examples, fn row ->
        [
          "entity=#{row.entity} condition=#{row.condition} terminal=#{row.terminal}",
          "  withdrawal_start active_generated=#{inspect(row.audit.active_generated)}",
          "  action_support=#{inspect(row.audit.action_support)}",
          "  motor_memory=#{inspect(row.audit.motor_memory)}",
          "  generated_labels=#{inspect(row.audit.generated_labels)}",
          "  generated_edges=#{inspect(row.audit.generated_edges)}",
          "  actions=#{Enum.join(Enum.map(row.records, &Atom.to_string(&1.action)), ",")}"
        ]
      end)

    Enum.join(["Home-foraging generated-memory audit" | lines] ++ ["EXAMPLES" | example_lines], "\n")
  end

  defp run_one(condition, width, total, seed, entity) do
    opts = Keyword.put(@field_opts, :encoding_salt, {:home_memory_audit, condition, entity})

    initial = %{
      field: DevelopmentalField.new(opts),
      position: @home,
      vitality: 0.92,
      warmth: 1.0,
      carrying: false,
      alive?: true,
      tick: 0,
      records: [],
      memory: Map.new(@actions, &{&1, 0.0}),
      withdrawal_audit: nil
    }

    final =
      Enum.reduce_while(1..total, initial, fn tick, prior ->
        stage = stage(tick, width)

        state =
          if stage == :withdrawal and prior.tick == width * 5 do
            audit = audit(prior.field, prior.memory, opts)
            %{prior | carrying: false, withdrawal_audit: audit}
          else
            prior
          end

        food = food_cell(stage)
        baseline = max(0.0, state.vitality - 0.006)
        warmth = update_warmth(state.warmth, state.position)
        hunger = 1.0 - baseline
        cold = 1.0 - warmth
        intended = choose(state, hunger, cold, tick, seed + entity * 137, opts)
        help = assist(condition, stage, intended, state, food, hunger, cold)
        action = help.action
        position = move(state.position, action)
        {carrying, intake, event} = interact(state.carrying, position, food, action, hunger)
        cost = action_cost(action, state.position, position, help.level) * 0.65
        vitality = max(0.0, min(1.0, baseline - cost - cold * 0.003 + intake))
        memory = remember(state.memory, intended, action, event, intake, help.level)

        features = features(stage, position, food, carrying, event, intended, help, action,
          hunger, warmth, cold, intake, vitality - state.vitality, warmth - state.warmth)
        field = DevelopmentalField.step(state.field, {:features, features}, opts)

        record = %{tick: tick, stage: stage, action: action, position: position, food: food,
          carrying: carrying, event: event, vitality: vitality, warmth: warmth}

        next = %{state | field: field, position: position, vitality: vitality, warmth: warmth,
          carrying: carrying, alive?: vitality > 0.0 and warmth > 0.0, tick: tick,
          records: [record | state.records], memory: memory}

        if next.alive?, do: {:cont, next}, else: {:halt, next}
      end)

    records = final.records |> Enum.reverse() |> Enum.filter(&(&1.stage == :withdrawal))
    collect_index = Enum.find_index(records, &(&1.event == :food_collected))

    returned =
      case collect_index do
        nil -> false
        index -> records |> Enum.drop(index + 1) |> Enum.any?(&(&1.carrying and &1.position == @home))
      end

    completed = Enum.any?(records, &(&1.event == :food_consumed_at_home))

    %{
      condition: condition,
      entity: entity,
      survived: final.alive? and final.tick == total,
      reached: Enum.any?(records, &(&1.position == &1.food)),
      collected: not is_nil(collect_index),
      returned: returned,
      completed: completed,
      terminal: terminal(completed, returned, collect_index, records),
      records: records,
      audit: final.withdrawal_audit || audit(final.field, final.memory, opts)
    }
  end

  defp audit(field, memory, opts) do
    generated = DevelopmentalField.generated_nodes(field)
    labels = label_nodes(generated, opts)

    generated_edges =
      field.edges
      |> Enum.filter(fn {{left, right}, weight} ->
        left >= field.micro_nodes and right >= field.micro_nodes and weight >= 0.001
      end)
      |> Enum.sort_by(fn {{left, right}, weight} -> {-weight, left, right} end)
      |> Enum.take(20)

    action_support = Map.new(@actions, &{&1, learned(field, &1, opts)})

    %{
      generated_count: length(generated),
      generated_edge_count: Enum.count(field.edges, fn {{left, right}, _} ->
        left >= field.micro_nodes and right >= field.micro_nodes
      end),
      spanning_count: Enum.count(labels, fn {_id, node_labels} -> spanning?(node_labels) end),
      active_generated: field.activity |> Enum.filter(fn {id, value} -> id >= field.micro_nodes and value >= 0.18 end)
        |> Enum.sort_by(fn {id, value} -> {-value, id} end) |> Enum.take(15),
      action_support: action_support,
      motor_memory: memory,
      generated_labels: labels |> Enum.filter(fn {_id, node_labels} -> node_labels != [] end) |> Enum.take(25),
      generated_edges: generated_edges
    }
  end

  defp label_nodes(nodes, opts) do
    probes = probe_features()

    Enum.map(nodes, fn node ->
      labels =
        probes
        |> Enum.filter(fn {_label, feature} ->
          encoded = DevelopmentalField.active_micro_nodes(DevelopmentalField.new(@field_opts), feature, opts)
          MapSet.size(MapSet.intersection(node.support, encoded)) >= 2
        end)
        |> Enum.map(&elem(&1, 0))

      {node.id, labels}
    end)
  end

  defp probe_features do
    [
      outbound: {:carrying_food, false},
      carrying: {:carrying_food, true},
      food_contact: {:food_relation, :contact},
      home_contact: {:home_relation, :contact},
      collected: {:foraging_event, :food_collected},
      consumed: {:foraging_event, :food_consumed_at_home},
      manipulate: {:motor_execution, :manipulate},
      north: {:motor_execution, :north},
      south: {:motor_execution, :south},
      east: {:motor_execution, :east},
      west: {:motor_execution, :west},
      hunger_high: {:body_channel, :hunger, :high},
      cold_high: {:body_channel, :cold_pressure, :high},
      intake: {:self_intake_channel, true}
    ]
  end

  defp spanning?(labels) do
    Enum.any?(labels, &(&1 in [:outbound, :food_contact, :collected])) and
      Enum.any?(labels, &(&1 in [:carrying, :home_contact])) and
      Enum.any?(labels, &(&1 in [:consumed, :intake]))
  end

  defp summarize(rows, population) do
    Map.new(@conditions, fn condition ->
      selected = Enum.filter(rows, &(&1.condition == condition))
      top_action =
        @actions
        |> Enum.map(fn action -> {action, median(Enum.map(selected, & &1.audit.action_support[action]))} end)
        |> Enum.max_by(&elem(&1, 1))
        |> elem(0)

      {condition, %{
        population: population,
        survived: Enum.count(selected, & &1.survived),
        reached: Enum.count(selected, & &1.reached),
        collected: Enum.count(selected, & &1.collected),
        returned: Enum.count(selected, & &1.returned),
        completed: Enum.count(selected, & &1.completed),
        generated: median(Enum.map(selected, & &1.audit.generated_count)),
        generated_edges: median(Enum.map(selected, & &1.audit.generated_edge_count)),
        spanning_nodes: median(Enum.map(selected, & &1.audit.spanning_count)),
        active_generated: median(Enum.map(selected, &(length(&1.audit.active_generated)))),
        top_action: top_action
      }}
    end)
  end

  defp examples(rows) do
    rows
    |> Enum.filter(&(&1.reached or &1.collected or &1.returned or &1.completed))
    |> Enum.take(8)
  end

  defp terminal(true, _, _, _), do: :completed
  defp terminal(_, true, _, _), do: :returned
  defp terminal(_, _, index, _) when not is_nil(index), do: :collected
  defp terminal(_, _, _, records), do: if(Enum.any?(records, &(&1.position == &1.food)), do: :reached, else: :none)

  defp features(stage, position, food, carrying, event, intended, help, action,
         hunger, warmth, cold, intake, vitality_delta, warmth_delta) do
    [
      {:development_stage, stage}, {:body_channel, :hunger, bucket(hunger)},
      {:body_channel, :warmth, bucket(warmth)}, {:body_channel, :cold_pressure, bucket(cold)},
      {:place_channel, position}, {:home_relation, relation(position, @home)},
      {:food_relation, relation(position, food)}, {:carrying_food, carrying},
      {:foraging_event, event}, {:motor_intention, intended}, {:caregiver_action, help.teacher},
      {:assistance_level, bucket(help.level)}, {:learner_action_ownership, :very_high},
      {:motor_execution, action}, {:self_intake_channel, intake > 0.0},
      {:change_channel, :vitality, trend(vitality_delta)}, {:change_channel, :warmth, trend(warmth_delta)}
    ]
  end

  defp choose(state, hunger, cold, tick, seed, opts) do
    @actions
    |> Enum.map(fn action ->
      exploration = :erlang.phash2({seed, tick, action}, 1_000) / 1_000 * 0.20
      pressure = max(hunger, cold) * 0.22
      wait_bias = if action == :wait, do: 0.18, else: 0.0
      {action, exploration + pressure + wait_bias + learned(state.field, action, opts) * 0.34 + state.memory[action] * 0.55}
    end)
    |> Enum.max_by(fn {action, score} -> {score, action} end)
    |> elem(0)
  end

  defp assist(:abrupt_assistance, stage, _intended, state, food, hunger, cold)
       when stage != :withdrawal and (hunger > 0.34 or cold > 0.30),
       do: help(guided_action(state, food), :activate, 1.0)
  defp assist(:abrupt_assistance, _, intended, _, _, _, _), do: help(intended, :none, 0.0)
  defp assist(:staged_assistance, stage, intended, state, food, hunger, cold)
       when stage != :withdrawal and (hunger > 0.30 or cold > 0.26) do
    target = guided_action(state, food)
    level = assistance_level(stage, intended == target)
    help(target, if(intended == target, do: :complete, else: :activate), level)
  end
  defp assist(:staged_assistance, _, intended, _, _, _, _), do: help(intended, :none, 0.0)

  defp assistance_level(:full_guidance, _), do: 1.0
  defp assistance_level(:co_produced, true), do: 0.55
  defp assistance_level(:co_produced, false), do: 0.80
  defp assistance_level(:local_independent, true), do: 0.30
  defp assistance_level(:local_independent, false), do: 0.60
  defp assistance_level(:guided_approach, true), do: 0.20
  defp assistance_level(:guided_approach, false), do: 0.45
  defp assistance_level(:near_independent, true), do: 0.10
  defp assistance_level(:near_independent, false), do: 0.30

  defp guided_action(%{carrying: false, position: position}, food) when position == food, do: :manipulate
  defp guided_action(%{carrying: false, position: position}, food), do: direction(position, food)
  defp guided_action(%{carrying: true, position: @home}, _food), do: :manipulate
  defp guided_action(%{carrying: true, position: position}, _food), do: direction(position, @home)
  defp help(action, :none, level), do: %{action: action, teacher: :none, level: level}
  defp help(action, mode, level), do: %{action: action, teacher: {:assist, action, mode}, level: level}

  defp interact(false, position, position, :manipulate, _), do: {true, 0.0, :food_collected}
  defp interact(true, @home, _, :manipulate, hunger), do: {false, min(0.34, 0.18 + hunger * 0.22), :food_consumed_at_home}
  defp interact(carrying, _, _, _, _), do: {carrying, 0.0, :none}
  defp update_warmth(warmth, @home), do: min(1.0, warmth + 0.12)
  defp update_warmth(warmth, _), do: max(0.0, warmth - 0.010)

  defp stage(tick, width) when tick <= width, do: :full_guidance
  defp stage(tick, width) when tick <= width * 2, do: :co_produced
  defp stage(tick, width) when tick <= width * 3, do: :local_independent
  defp stage(tick, width) when tick <= width * 4, do: :guided_approach
  defp stage(tick, width) when tick <= width * 5, do: :near_independent
  defp stage(_, _), do: :withdrawal
  defp food_cell(stage) when stage in [:full_guidance, :co_produced], do: {3, 0}
  defp food_cell(stage) when stage in [:local_independent, :guided_approach], do: {3, 2}
  defp food_cell(:near_independent), do: {2, 3}
  defp food_cell(:withdrawal), do: {3, 3}

  defp direction({x, _}, {tx, _}) when x < tx, do: :east
  defp direction({x, _}, {tx, _}) when x > tx, do: :west
  defp direction({_, y}, {_, ty}) when y < ty, do: :south
  defp direction({_, y}, {_, ty}) when y > ty, do: :north
  defp direction(position, position), do: :wait
  defp move(position, action) when action in [:manipulate, :wait], do: position
  defp move({x, y}, :north), do: {x, max(0, y - 1)}
  defp move({x, y}, :south), do: {x, min(3, y + 1)}
  defp move({x, y}, :east), do: {min(3, x + 1), y}
  defp move({x, y}, :west), do: {max(0, x - 1), y}
  defp action_cost(:wait, _, _, level), do: 0.002 * effort(level)
  defp action_cost(:manipulate, _, _, level), do: 0.004 * effort(level)
  defp action_cost(_, position, position, level), do: 0.008 * effort(level)
  defp action_cost(_, _, _, level), do: 0.010 * effort(level)
  defp effort(level), do: max(0.25, 1.0 - level * 0.75)

  defp remember(memory, intended, action, event, intake, assistance) do
    decayed = Map.new(memory, fn {stored, value} -> {stored, value * 0.992} end)
    consequence = intake + if(event == :food_collected, do: 0.08, else: 0.0)
    gain = consequence * (0.45 + (1.0 - assistance) * 0.55)
    next = Map.update!(decayed, action, &min(1.0, &1 + gain))
    if intended == action, do: Map.update!(next, intended, &min(1.0, &1 + gain * 0.45)), else: next
  end

  defp learned(field, action, opts) do
    targets = DevelopmentalField.active_micro_nodes(field, {:motor_execution, action}, opts)
    Enum.reduce(field.activity, 0.0, fn {source, activity}, total ->
      if activity >= 0.18 do
        total + Enum.reduce(targets, 0.0, fn target, acc -> acc + Map.get(field.edges, {source, target}, 0.0) * activity end)
      else
        total
      end
    end)
  end

  defp relation(position, position), do: :contact
  defp relation({x, y}, {tx, ty}) when abs(x - tx) + abs(y - ty) == 1, do: :adjacent
  defp relation(_, _), do: :distant
  defp bucket(value) when value < 0.25, do: :very_low
  defp bucket(value) when value < 0.50, do: :low
  defp bucket(value) when value < 0.75, do: :high
  defp bucket(_), do: :very_high
  defp trend(delta) when delta > 0.01, do: :rising
  defp trend(delta) when delta < -0.01, do: :falling
  defp trend(_), do: :stable
  defp median([]), do: 0.0
  defp median(values) do
    sorted = Enum.sort(values)
    middle = div(length(sorted), 2)
    if rem(length(sorted), 2) == 1, do: Enum.at(sorted, middle) * 1.0,
      else: (Enum.at(sorted, middle - 1) + Enum.at(sorted, middle)) / 2
  end
  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 1)
end
