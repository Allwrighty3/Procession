defmodule Procession.Simulation.LivingBriarTest do
  use ExUnit.Case, async: false

  alias Procession.Demo
  alias Procession.Simulation.LivingBriar

  test "canonical scenario exposes structured causal evidence" do
    run = LivingBriar.run(ticks: 24, budget: 3, cadence: 1, seed: 41)

    assert run.scenario == :living_briar
    assert run.configuration == %{ticks: 24, budget: 3, cadence: 1, seed: 41}
    assert length(run.observations) == 24
    assert run.summary.decisions > 0
    assert run.summary.failures == 0
    assert run.summary.archived_minds_committed?
    assert abs(run.summary.material_accounting_error) < 1.0e-8

    assert Enum.any?(run.observations, fn observation -> observation.decisions != [] end)

    assert Enum.all?(LivingBriar.changes(run), fn observation ->
             Enum.all?(observation.decisions, fn
               %{result: :failed} -> true
               decision ->
                 Map.has_key?(decision, :motor_pattern) and
                   Map.has_key?(decision, :physical_consequence) and
                   Map.has_key?(decision, :mind_committed?)
             end)
           end)
  end

  test "IEx demo boundary uses the same canonical scenario" do
    run = Demo.living_briar(ticks: 8, budget: 2, seed: 19)

    assert run.scenario == :living_briar
    assert run.configuration.ticks == 8
    assert run.configuration.budget == 2
    assert is_binary(LivingBriar.format(run))
    assert LivingBriar.latest(run).tick == 8
  end

  test "compact text includes observable physical changes without hidden goals" do
    text =
      LivingBriar.run(ticks: 12, budget: 3, seed: 77)
      |> LivingBriar.format()

    assert text =~ "Living Briar"
    assert text =~ "final populations"
    refute text =~ "correct route"
    refute text =~ "goal accomplished"
    refute text =~ "journey complete"
  end
end
