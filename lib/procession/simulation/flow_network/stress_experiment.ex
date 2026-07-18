defmodule Procession.Simulation.FlowNetwork.StressExperiment do
  @moduledoc """
  Noncognitive reference experiment for the general flow substrate.

  Present couplings:
  - local stress propagation
  - explicit unresolved output
  - history-dependent structural weakening
  - later propagation through the changed structure

  Missing couplings:
  - geometry and real units
  - elastic rebound
  - heat and sound receivers
  - repair, chemistry, and surrounding material

  Therefore this experiment demonstrates architecture, not engineering accuracy.
  """

  alias Procession.Simulation.FlowNetwork

  defmodule StressDamage do
    @moduledoc false
    @behaviour Procession.Simulation.FlowNetwork.ResponseLaw

    @impl true
    def apply(network, result, opts) do
      threshold = Keyword.get(opts, :fracture_threshold, 0.14)
      weakening = Keyword.get(opts, :weakening, 1.8)

      Enum.reduce(result.flows, {network, []}, fn {edge, flow}, {current, events} ->
        if flow >= threshold do
          {from, to} = edge
          old = FlowNetwork.resistance(current, from, to)
          updated = FlowNetwork.put_resistance(current, from, to, old * weakening)
          event = %{type: :weakened, edge: edge, flow: flow, resistance_before: old, resistance_after: old * weakening}
          {updated, [event | events]}
        else
          {current, events}
        end
      end)
      |> then(fn {updated, events} -> {updated, Enum.reverse(events)} end)
    end
  end

  @spec network() :: FlowNetwork.t()
  def network do
    FlowNetwork.new()
    |> FlowNetwork.add_transition(:impact, :near, resistance: 0.35)
    |> FlowNetwork.add_transition(:near, :motion, resistance: 0.35)
    |> FlowNetwork.add_transition(:impact, :far, resistance: 0.85)
    |> FlowNetwork.add_transition(:far, :motion, resistance: 0.55)
  end

  @spec run(keyword()) :: map()
  def run(opts \\ []) do
    quantity = Keyword.get(opts, :impact, 1.0)
    flow_opts = [threshold: 0.001, attenuation: 0.98, permeability_scale: 0.45, max_ticks: 4]
    initial = network()
    first = FlowNetwork.run(initial, %{impact: quantity}, [:motion], flow_opts)
    {damaged, events} = StressDamage.apply(initial, first, opts)
    second = FlowNetwork.run(damaged, %{impact: quantity}, [:motion], flow_opts)

    %{
      initial_network: initial,
      damaged_network: damaged,
      first: first,
      second: second,
      events: events,
      report: report(first, second, events)
    }
  end

  @spec missing_couplings() :: [atom()]
  def missing_couplings, do: [:geometry, :real_units, :elastic_rebound, :heat_receiver, :sound_receiver, :repair]

  defp report(first, second, events) do
    """
    First impact
    transferred motion: #{format(total(first.transferred))}
    unresolved conversion: #{format(first.unresolved)}
    near-path flow: #{format(Map.get(first.flows, {:impact, :near}, 0.0))}
    far-path flow: #{format(Map.get(first.flows, {:impact, :far}, 0.0))}

    Structural changes: #{length(events)}

    Second impact
    transferred motion: #{format(total(second.transferred))}
    unresolved conversion: #{format(second.unresolved)}
    near-path flow: #{format(Map.get(second.flows, {:impact, :near}, 0.0))}
    far-path flow: #{format(Map.get(second.flows, {:impact, :far}, 0.0))}
    """
    |> String.trim()
  end

  defp total(map), do: Enum.reduce(map, 0.0, fn {_key, value}, acc -> acc + value end)
  defp format(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
