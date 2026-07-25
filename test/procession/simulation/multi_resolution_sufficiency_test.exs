defmodule Procession.Simulation.MultiResolutionSufficiencyTest do
  use ExUnit.Case, async: true

  alias Procession.Simulation.DevelopmentalSensorimotorField
  alias Procession.TestSupport.MultiResolutionWorldHarness, as: World

  describe "mental plane sufficiency contracts" do
    test "different histories remain behaviorally distinguishable" do
      baseline = World.new()
      injured = World.injure(baseline, "mara", 0.85)
      betrayed = World.betray(baseline, "oren", "mara", 0.85)

      injured = World.run(injured, 40)
      betrayed = World.run(betrayed, 40)

      assert World.distance(World.future_vector(injured), World.future_vector(betrayed)) > 0.05
      assert :injury_history in World.compress(injured).causal_flags
      assert :betrayal_history in World.compress(betrayed).causal_flags
    end

    test "extreme events persist longer than ordinary events but still decay" do
      opts = World.mental_opts(activity_retention: 0.0)

      ordinary =
        DevelopmentalSensorimotorField.new(opts)
        |> DevelopmentalSensorimotorField.sense([{:signal, :impact, 1.0}], opts)

      extreme =
        DevelopmentalSensorimotorField.new(opts)
        |> DevelopmentalSensorimotorField.sense([{:signal, :impact, 8.0}], opts)

      ordinary_later = Enum.reduce(1..40, ordinary, fn _, state -> DevelopmentalSensorimotorField.sense(state, [], opts) end)
      extreme_later = Enum.reduce(1..40, extreme, fn _, state -> DevelopmentalSensorimotorField.sense(state, [], opts) end)

      ordinary_mass = Enum.sum(Map.values(ordinary_later.sensory.activity))
      extreme_mass = Enum.sum(Map.values(extreme_later.sensory.activity))

      assert extreme_mass > ordinary_mass
      assert extreme_mass < Enum.sum(Map.values(extreme.sensory.activity))
      assert map_size(extreme_later.salience.imprints) > 0
    end

    test "habituation prevents harmless repeated background from dominating novel input" do
      opts = World.mental_opts(activity_retention: 0.0, salience_learning_slots: 1)

      habituated =
        Enum.reduce(1..25, DevelopmentalSensorimotorField.new(opts), fn _, state ->
          DevelopmentalSensorimotorField.sense(state, [:clock_tick], opts)
        end)

      novel = DevelopmentalSensorimotorField.sense(habituated, [:clock_tick, :falling_book], opts)
      admitted = DevelopmentalSensorimotorField.salience_metrics(novel).admitted_features

      assert :falling_book in admitted
      refute :clock_tick in admitted
    end

    test "ablation of salience erases magnitude-sensitive divergence" do
      enabled = World.mental_opts(dynamic_salience: true, activity_retention: 0.0)
      disabled = World.mental_opts(dynamic_salience: false, activity_retention: 0.0)

      enabled_low = DevelopmentalSensorimotorField.new(enabled) |> DevelopmentalSensorimotorField.sense([{:signal, :pain, 1.0}], enabled)
      enabled_high = DevelopmentalSensorimotorField.new(enabled) |> DevelopmentalSensorimotorField.sense([{:signal, :pain, 7.0}], enabled)
      disabled_low = DevelopmentalSensorimotorField.new(disabled) |> DevelopmentalSensorimotorField.sense([{:signal, :pain, 1.0}], disabled)
      disabled_high = DevelopmentalSensorimotorField.new(disabled) |> DevelopmentalSensorimotorField.sense([{:signal, :pain, 7.0}], disabled)

      enabled_gap = abs(activity_mass(enabled_high) - activity_mass(enabled_low))
      disabled_gap = abs(activity_mass(disabled_high) - activity_mass(disabled_low))

      assert enabled_gap > disabled_gap + 0.5
    end
  end

  describe "physical plane contracts" do
    test "injury changes mobility, labor, and resource trajectory without a scripted scenario chain" do
      control = World.new() |> World.run(100)
      injured = World.new() |> World.injure("mara", 0.9) |> World.run(100)

      control_summary = World.compress(control)
      injured_summary = World.compress(injured)

      assert injured_summary.mean_mobility < control_summary.mean_mobility
      assert injured_summary.mean_vitality < control_summary.mean_vitality
      assert injured_summary.reserve < control_summary.reserve
      assert injured_summary.food_pressure > control_summary.food_pressure
    end

    test "physical access intervention produces persistent settlement-scale divergence" do
      control = World.new() |> World.run(80)
      disrupted = World.new() |> World.destroy_bridge(1.0) |> World.run(80)

      assert World.compress(disrupted).migration_pressure > World.compress(control).migration_pressure
      assert :access_disruption in World.compress(disrupted).causal_flags
    end

    test "local physical damage does not directly mutate unrelated mental state" do
      before = World.new()
      sela_before = before.people["sela"].mental
      after_world = World.injure(before, "mara", 1.0)
      sela_after = after_world.people["sela"].mental

      assert sela_after.sensory.tick == sela_before.sensory.tick
      assert sela_after.sensory.activity == sela_before.sensory.activity
    end
  end

  describe "social and institutional plane contracts" do
    test "betrayal affects interpersonal trust and can propagate to institutional trust" do
      baseline = World.new()
      betrayed = World.betray(baseline, "oren", "mara", 0.9)

      assert betrayed.people["mara"].trust["oren"] < 0.2
      assert betrayed.institutions.distribution_trust < baseline.institutions.distribution_trust
      assert map_size(betrayed.people["mara"].mental.salience.imprints) > 0
    end

    test "social support alters physical recovery without directly setting outcomes" do
      supported = World.new() |> World.injure("mara", 0.75) |> World.run(100, social_support: true)
      isolated = World.new() |> World.injure("mara", 0.75) |> World.run(100, social_support: false)

      assert supported.people["mara"].vitality > isolated.people["mara"].vitality
      assert supported.people["mara"].injury < isolated.people["mara"].injury
      assert supported.institutions.obligation_strength > isolated.institutions.obligation_strength
    end

    test "institutional failure changes household and settlement outcomes" do
      working = World.new() |> World.run(100, distribution: true)
      failed = World.new() |> World.run(100, distribution: false)

      working_summary = World.compress(working)
      failed_summary = World.compress(failed)

      assert failed_summary.food_pressure > working_summary.food_pressure
      assert failed_summary.migration_pressure > working_summary.migration_pressure
      assert failed_summary.conflict_pressure > working_summary.conflict_pressure
      assert failed_summary.mean_vitality < working_summary.mean_vitality
    end
  end

  describe "cross-layer causal transmission" do
    test "one intervention crosses mental, physical, household, and settlement layers" do
      world = World.new() |> World.injure("mara", 0.95) |> World.run(120)
      summary = World.compress(world)

      assert map_size(world.people["mara"].mental.salience.imprints) > 0
      assert world.people["mara"].mobility < 0.6
      assert world.households["north"].food < 1.4
      assert summary.food_pressure > 0.0
      assert summary.migration_pressure > 0.0
    end

    test "novel combinations interact without a named combined scenario" do
      combined =
        World.new()
        |> World.injure("mara", 0.8)
        |> World.betray("oren", "mara", 0.8)
        |> World.destroy_bridge(0.8)
        |> World.run(120, social_support: false)

      isolated_injury = World.new() |> World.injure("mara", 0.8) |> World.run(120)

      combined_summary = World.compress(combined)
      isolated_summary = World.compress(isolated_injury)

      assert combined_summary.mean_vitality < isolated_summary.mean_vitality
      assert combined_summary.migration_pressure > isolated_summary.migration_pressure
      assert combined_summary.conflict_pressure > isolated_summary.conflict_pressure
      assert Enum.sort(combined_summary.causal_flags) ==
               Enum.sort([:access_disruption, :betrayal_history, :injury_history])
    end
  end

  describe "multi-resolution continuity" do
    test "fine to coarse to fine round trip preserves future causal envelope" do
      fine =
        World.new()
        |> World.injure("mara", 0.7)
        |> World.betray("oren", "mara", 0.6)
        |> World.run(60)

      continuously_fine = World.run(fine, 80)

      round_trip =
        fine
        |> World.compress()
        |> World.coarse_run(40)
        |> World.refine(41)
        |> World.run(40)

      assert World.distance(World.future_vector(continuously_fine), World.future_vector(round_trip)) < 1.25
      assert :injury_history in World.compress(round_trip).causal_flags
      assert :betrayal_history in World.compress(round_trip).causal_flags
    end

    test "coarse summary supports multiple microstates without changing aggregate commitments" do
      summary =
        World.new()
        |> World.injure("mara", 0.5)
        |> World.run(30)
        |> World.compress()

      left = World.refine(summary, 1)
      right = World.refine(summary, 99)

      refute left.people == right.people
      assert World.distance(World.future_vector(left), World.future_vector(right)) < 0.05
      assert World.compress(left).causal_flags == World.compress(right).causal_flags
    end

    test "coarse intervention has the same causal direction after refinement" do
      baseline = World.new() |> World.run(30) |> World.compress()
      stable = baseline |> World.coarse_run(50, food_shock: 0.0) |> World.refine(7) |> World.run(30)
      shocked = baseline |> World.coarse_run(50, food_shock: 0.01) |> World.refine(7) |> World.run(30)

      stable_summary = World.compress(stable)
      shocked_summary = World.compress(shocked)

      assert shocked_summary.food_pressure > stable_summary.food_pressure
      assert shocked_summary.migration_pressure > stable_summary.migration_pressure
      assert shocked_summary.mean_vitality < stable_summary.mean_vitality
    end
  end

  describe "compression and computational viability" do
    test "summary is substantially cheaper than live state while retaining causal flags" do
      world =
        World.new()
        |> World.injure("mara", 0.8)
        |> World.betray("oren", "mara", 0.7)
        |> World.run(100)

      summary = World.compress(world)

      assert World.summary_cost(summary) * 5 < World.state_cost(world)
      assert :injury_history in summary.causal_flags
      assert :betrayal_history in summary.causal_flags
    end

    test "summary cost is independent of elapsed fine-resolution history" do
      short = World.new() |> World.run(10) |> World.compress()
      long = World.new() |> World.run(500) |> World.compress()

      assert World.summary_cost(short) == World.summary_cost(long)
    end

    test "mental active mass remains bounded under many simultaneous signals" do
      opts = World.mental_opts(salience_capacity: 10.0)
      signals = Enum.map(1..100, &{:signal, {:crowd_signal, &1}, 3.0})

      field =
        DevelopmentalSensorimotorField.new(opts)
        |> DevelopmentalSensorimotorField.sense(signals, opts)

      assert activity_mass(field) <= 10.000_001
    end
  end

  defp activity_mass(field), do: Enum.sum(Map.values(field.sensory.activity))
end
