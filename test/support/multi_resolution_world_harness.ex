defmodule Procession.TestSupport.MultiResolutionWorldHarness do
  @moduledoc false

  alias Procession.Simulation.DevelopmentalSensorimotorField

  @mental_opts [
    dynamic_salience: true,
    micro_nodes: 96,
    input_width: 4,
    encoding_salt: :multi_resolution_world,
    activity_retention: 0.72,
    salience_capacity: 18.0,
    salience_learning_slots: 8,
    salience_novelty_gain: 0.35,
    salience_habituation_rate: 0.08,
    extreme_salience_threshold: 3.0,
    extreme_salience_imprint_retention: 0.997,
    extreme_salience_intrusion: 0.015,
    extreme_salience_cue_gain: 0.35
  ]

  defstruct tick: 0,
            people: %{},
            households: %{},
            settlement: %{food: 0.0, reserve: 0.0, migration_pressure: 0.0, conflict_pressure: 0.0},
            institutions: %{distribution_trust: 1.0, obligation_strength: 1.0},
            event_log: []

  def new(opts \\ []) do
    people =
      opts
      |> Keyword.get(:people, default_people())
      |> Map.new(fn {id, attrs} -> {id, new_person(id, attrs)} end)

    households =
      opts
      |> Keyword.get(:households, default_households())
      |> Map.new()

    settlement = Map.merge(%{food: 24.0, reserve: 8.0, migration_pressure: 0.0, conflict_pressure: 0.0}, Keyword.get(opts, :settlement, %{}))
    institutions = Map.merge(%{distribution_trust: 1.0, obligation_strength: 1.0}, Keyword.get(opts, :institutions, %{}))

    %__MODULE__{people: people, households: households, settlement: settlement, institutions: institutions}
  end

  def mental_opts(overrides \\ []), do: Keyword.merge(@mental_opts, overrides)

  def expose(%__MODULE__{} = world, person_id, signals, opts \\ []) do
    update_in(world.people[person_id], fn person ->
      mental = DevelopmentalSensorimotorField.sense(person.mental, signals, mental_opts(opts))
      %{person | mental: mental}
    end)
  end

  def injure(%__MODULE__{} = world, person_id, severity) when is_number(severity) do
    severity = clamp(severity, 0.0, 1.0)

    world
    |> update_in([Access.key(:people), person_id], fn person ->
      %{person | injury: max(person.injury, severity), mobility: min(person.mobility, 1.0 - severity * 0.8)}
    end)
    |> expose(person_id, [{:signal, {:body, :injury}, 1.0 + severity * 7.0}])
    |> log({:injury, person_id, severity})
  end

  def betray(%__MODULE__{} = world, source, target, severity) do
    severity = clamp(severity, 0.0, 1.0)

    world
    |> update_in([Access.key(:people), target, Access.key(:trust)], fn trust ->
      Map.update(trust, source, 1.0 - severity, &max(0.0, &1 - severity))
    end)
    |> expose(target, [{:signal, {:social, :betrayal, source}, 1.0 + severity * 6.0}])
    |> update_in([Access.key(:institutions), Access.key(:distribution_trust)], &max(0.0, &1 - severity * 0.15))
    |> log({:betrayal, source, target, severity})
  end

  def destroy_bridge(%__MODULE__{} = world, severity \\ 1.0) do
    severity = clamp(severity, 0.0, 1.0)

    world
    |> update_in([Access.key(:settlement), Access.key(:reserve)], &max(0.0, &1 - 2.0 * severity))
    |> update_in([Access.key(:settlement), Access.key(:migration_pressure)], &min(1.0, &1 + 0.25 * severity))
    |> log({:bridge_destroyed, severity})
  end

  def step(%__MODULE__{} = world, opts \\ []) do
    support? = Keyword.get(opts, :social_support, true)
    distribution? = Keyword.get(opts, :distribution, true)

    {person_rows, labor} =
      Enum.map_reduce(world.people, 0.0, fn {id, person}, total ->
        household = Map.fetch!(world.households, person.household_id)
        hunger_pressure = clamp((0.55 - household.food / max(length(household.members), 1)) / 0.55, 0.0, 1.0)
        support = if support?, do: household_support(world, household, id), else: 0.0
        vitality = clamp(person.vitality - 0.012 - person.injury * 0.018 - hunger_pressure * 0.02 + support * 0.01, 0.0, 1.0)
        mobility = clamp(person.mobility + (1.0 - person.injury) * 0.01 - person.injury * 0.004, 0.0, 1.0)
        injury = clamp(person.injury * 0.992 - support * 0.002, 0.0, 1.0)
        productivity = vitality * mobility * (1.0 - injury)

        signals = [
          {:signal, {:body, :hunger_pressure}, 1.0 + hunger_pressure * 4.0},
          {:signal, {:body, :injury}, person.injury * 5.0},
          {:signal, {:social, :support}, support * 3.0}
        ]

        mental = DevelopmentalSensorimotorField.sense(person.mental, signals, mental_opts())
        updated = %{person | vitality: vitality, mobility: mobility, injury: injury, mental: mental}
        {{id, updated}, total + productivity}
      end)

    people = Map.new(person_rows)
    produced = labor * Keyword.get(opts, :food_per_labor, 0.12)
    settlement_food = world.settlement.food + produced
    available = if distribution?, do: settlement_food * world.institutions.distribution_trust, else: 0.0

    {households, consumed} = distribute_household_food(world.households, available)
    settlement_food = max(0.0, settlement_food - consumed)

    unmet =
      Enum.sum(Map.values(households), fn household ->
        max(0.0, length(household.members) * 0.55 - household.food)
      end)

    population = max(map_size(people), 1)
    food_pressure = clamp(unmet / population, 0.0, 1.0)
    low_trust = 1.0 - world.institutions.distribution_trust

    settlement = %{world.settlement |
      food: settlement_food,
      reserve: max(0.0, world.settlement.reserve + produced * 0.15 - food_pressure * 0.08),
      migration_pressure: clamp(world.settlement.migration_pressure * 0.97 + food_pressure * 0.08, 0.0, 1.0),
      conflict_pressure: clamp(world.settlement.conflict_pressure * 0.96 + food_pressure * 0.04 + low_trust * 0.03, 0.0, 1.0)
    }

    institutions = %{world.institutions |
      distribution_trust: clamp(world.institutions.distribution_trust + if(distribution? and food_pressure < 0.2, do: 0.002, else: -food_pressure * 0.003), 0.0, 1.0),
      obligation_strength: clamp(world.institutions.obligation_strength * 0.999 + if(support?, do: 0.001, else: -0.002), 0.0, 1.0)
    }

    %{world | tick: world.tick + 1, people: people, households: households, settlement: settlement, institutions: institutions}
  end

  def run(world, ticks, opts \\ []) do
    Enum.reduce(1..ticks, world, fn _, state -> step(state, opts) end)
  end

  def compress(%__MODULE__{} = world) do
    people = Map.values(world.people)
    households = Map.values(world.households)

    %{
      tick: world.tick,
      population: length(people),
      household_count: length(households),
      mean_vitality: mean(Enum.map(people, & &1.vitality)),
      mean_mobility: mean(Enum.map(people, & &1.mobility)),
      injury_pressure: mean(Enum.map(people, & &1.injury)),
      food_pressure: mean(Enum.map(households, fn h -> max(0.0, length(h.members) * 0.55 - h.food) end)),
      distribution_trust: world.institutions.distribution_trust,
      obligation_strength: world.institutions.obligation_strength,
      migration_pressure: world.settlement.migration_pressure,
      conflict_pressure: world.settlement.conflict_pressure,
      reserve: world.settlement.reserve,
      causal_flags: causal_flags(world)
    }
  end

  def coarse_step(summary, opts \\ []) do
    shock = Keyword.get(opts, :food_shock, 0.0)
    support = Keyword.get(opts, :institutional_support, 1.0)
    injury_drag = summary.injury_pressure * 0.012
    food_pressure = clamp(summary.food_pressure + shock + injury_drag - summary.reserve * 0.002, 0.0, 1.0)
    trust = clamp(summary.distribution_trust - food_pressure * 0.002 + support * 0.001, 0.0, 1.0)

    %{summary |
      tick: summary.tick + 1,
      mean_vitality: clamp(summary.mean_vitality - 0.008 - injury_drag - food_pressure * 0.012, 0.0, 1.0),
      mean_mobility: clamp(summary.mean_mobility - summary.injury_pressure * 0.004, 0.0, 1.0),
      injury_pressure: clamp(summary.injury_pressure * 0.993, 0.0, 1.0),
      food_pressure: food_pressure,
      distribution_trust: trust,
      obligation_strength: clamp(summary.obligation_strength + support * 0.001 - food_pressure * 0.001, 0.0, 1.0),
      migration_pressure: clamp(summary.migration_pressure * 0.98 + food_pressure * 0.05, 0.0, 1.0),
      conflict_pressure: clamp(summary.conflict_pressure * 0.97 + food_pressure * 0.025 + (1.0 - trust) * 0.02, 0.0, 1.0),
      reserve: max(0.0, summary.reserve - food_pressure * 0.05)
    }
  end

  def coarse_run(summary, ticks, opts \\ []) do
    Enum.reduce(1..ticks, summary, fn _, state -> coarse_step(state, opts) end)
  end

  def refine(summary, seed \\ 1) do
    population = summary.population
    household_count = max(summary.household_count, 1)

    people =
      Map.new(1..population, fn index ->
        id = "refined_#{seed}_#{index}"
        household_id = "household_#{rem(index - 1, household_count) + 1}"
        variation = (:erlang.phash2({seed, index}, 2001) - 1000) / 100_000

        {id,
         %{
           household_id: household_id,
           vitality: clamp(summary.mean_vitality + variation, 0.0, 1.0),
           mobility: clamp(summary.mean_mobility - variation, 0.0, 1.0),
           injury: clamp(summary.injury_pressure + variation, 0.0, 1.0),
           trust: %{},
           mental: DevelopmentalSensorimotorField.new(mental_opts())
         }}
      end)

    households =
      Map.new(1..household_count, fn index ->
        id = "household_#{index}"
        members = people |> Enum.filter(fn {_pid, p} -> p.household_id == id end) |> Enum.map(&elem(&1, 0))
        per_household_pressure = summary.food_pressure / household_count
        food = max(0.0, length(members) * 0.55 - per_household_pressure)
        {id, %{members: members, food: food}}
      end)

    %__MODULE__{
      tick: summary.tick,
      people: people,
      households: households,
      settlement: %{food: 0.0, reserve: summary.reserve, migration_pressure: summary.migration_pressure, conflict_pressure: summary.conflict_pressure},
      institutions: %{distribution_trust: summary.distribution_trust, obligation_strength: summary.obligation_strength},
      event_log: [{:refined_from_summary, summary.causal_flags}]
    }
  end

  def future_vector(%__MODULE__{} = world), do: future_vector(compress(world))

  def future_vector(summary) do
    [
      summary.mean_vitality,
      summary.mean_mobility,
      summary.injury_pressure,
      summary.food_pressure,
      summary.distribution_trust,
      summary.obligation_strength,
      summary.migration_pressure,
      summary.conflict_pressure,
      summary.reserve
    ]
  end

  def distance(left, right) do
    left
    |> Enum.zip(right)
    |> Enum.map(fn {a, b} -> abs(a - b) end)
    |> Enum.sum()
  end

  def state_cost(%__MODULE__{} = world) do
    mental =
      Enum.sum(Map.values(world.people), fn person ->
        map_size(person.mental.sensory.nodes) + map_size(person.mental.sensory.edges) +
          map_size(person.mental.sensory.activity) + map_size(person.mental.salience.imprints)
      end)

    mental + map_size(world.people) + map_size(world.households) * 2 + map_size(world.institutions) + map_size(world.settlement)
  end

  def summary_cost(summary), do: map_size(summary) + length(summary.causal_flags)

  defp new_person(id, attrs) do
    %{
      id: id,
      household_id: Map.fetch!(attrs, :household_id),
      vitality: Map.get(attrs, :vitality, 1.0),
      mobility: Map.get(attrs, :mobility, 1.0),
      injury: Map.get(attrs, :injury, 0.0),
      trust: Map.get(attrs, :trust, %{}),
      mental: DevelopmentalSensorimotorField.new(mental_opts(encoding_salt: {:multi_resolution_world, id}))
    }
  end

  defp default_people do
    %{
      "mara" => %{household_id: "north"},
      "oren" => %{household_id: "north"},
      "sela" => %{household_id: "south"},
      "tomas" => %{household_id: "south"}
    }
  end

  defp default_households do
    %{
      "north" => %{members: ["mara", "oren"], food: 1.4},
      "south" => %{members: ["sela", "tomas"], food: 1.4}
    }
  end

  defp household_support(world, household, person_id) do
    peers = Enum.reject(household.members, &(&1 == person_id))

    if peers == [] do
      0.0
    else
      peer_vitality = mean(Enum.map(peers, &world.people[&1].vitality))
      peer_vitality * world.institutions.obligation_strength
    end
  end

  defp distribute_household_food(households, available) do
    total_need = Enum.sum(Map.values(households), fn household -> max(0.0, length(household.members) * 0.55 - household.food) end)

    if total_need <= 0.0 or available <= 0.0 do
      {households, 0.0}
    else
      consumed = min(available, total_need)

      updated =
        Map.new(households, fn {id, household} ->
          need = max(0.0, length(household.members) * 0.55 - household.food)
          share = consumed * need / total_need
          {id, %{household | food: household.food + share}}
        end)

      {updated, consumed}
    end
  end

  defp causal_flags(world) do
    []
    |> maybe_flag(Enum.any?(world.event_log, &match?({:injury, _, _}, &1)), :injury_history)
    |> maybe_flag(Enum.any?(world.event_log, &match?({:betrayal, _, _, _}, &1)), :betrayal_history)
    |> maybe_flag(Enum.any?(world.event_log, &match?({:bridge_destroyed, _}, &1)), :access_disruption)
    |> maybe_flag(world.institutions.distribution_trust < 0.65, :low_distribution_trust)
    |> maybe_flag(world.settlement.migration_pressure > 0.4, :migration_risk)
    |> Enum.sort()
  end

  defp maybe_flag(flags, true, flag), do: [flag | flags]
  defp maybe_flag(flags, false, _flag), do: flags

  defp log(world, event), do: %{world | event_log: [event | world.event_log]}
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
end
