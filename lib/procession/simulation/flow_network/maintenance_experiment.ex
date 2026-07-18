defmodule Procession.Simulation.FlowNetwork.MaintenanceExperiment do
  @moduledoc """
  Minimal nonintelligent self-maintaining circulation experiment.

  Present couplings:
  - finite stored throughput
  - external replenishment
  - competing maintenance and action exits
  - persistence dependent on funded maintenance

  Missing couplings:
  - sensing and cognition
  - damage types and repair processes
  - temperature, matter conversion, and waste
  - other entities and developmental history

  The experiment should not yet produce hunger, shelter-seeking, attachment,
  curiosity, or planning. It only establishes a prerequisite for those systems.
  """

  alias Procession.Simulation.FlowNetwork

  defmodule State do
    @moduledoc false
    defstruct tick: 0,
              store: 0.6,
              integrity: 1.0,
              persisted: true,
              total_intake: 0.0,
              maintenance_used: 0.0,
              action_used: 0.0,
              unresolved: 0.0,
              history: []
  end

  @spec network() :: FlowNetwork.t()
  def network do
    FlowNetwork.new()
    |> FlowNetwork.add_transition(:available, :maintenance, resistance: 0.32)
    |> FlowNetwork.add_transition(:available, :action, resistance: 0.62)
  end

  @spec run(keyword()) :: State.t()
  def run(opts \\ []) do
    ticks = Keyword.get(opts, :ticks, 80)
    intake = Keyword.get(opts, :intake, fn tick -> if rem(tick, 5) == 0, do: 0.22, else: 0.0 end)
    initial = %State{store: Keyword.get(opts, :initial_store, 0.6)}

    if ticks <= 0 do
      initial
    else
      Enum.reduce_while(1..ticks, initial, fn tick, state ->
        next = advance(state, tick, intake, opts)
        if next.persisted, do: {:cont, next}, else: {:halt, next}
      end)
    end
  end

  @spec report(State.t()) :: String.t()
  def report(state) do
    """
    ticks completed: #{state.tick}
    external intake: #{format(state.total_intake)}
    maintenance used: #{format(state.maintenance_used)}
    action used: #{format(state.action_used)}
    unresolved conversion: #{format(state.unresolved)}
    remaining store: #{format(state.store)}
    integrity: #{format(state.integrity)}
    pattern persisted: #{state.persisted}
    """
    |> String.trim()
  end

  @spec missing_couplings() :: [atom()]
  def missing_couplings do
    [:sensing, :cognition, :damage_types, :repair, :temperature, :matter_conversion,
     :waste, :other_entities, :development]
  end

  defp advance(state, tick, intake_fun, opts) do
    intake = max(0.0, intake_fun.(tick) * 1.0)
    available = state.store + intake
    spend_limit = min(available, Keyword.get(opts, :max_throughput, 0.18))

    result =
      FlowNetwork.run(network(), %{available: spend_limit}, [:maintenance, :action],
        threshold: 0.0001,
        attenuation: 0.99,
        permeability_scale: 0.25,
        max_ticks: 2
      )

    maintenance = Map.get(result.transferred, :maintenance, 0.0)
    action = Map.get(result.transferred, :action, 0.0)
    spent = maintenance + action + result.unresolved
    requirement = Keyword.get(opts, :maintenance_requirement, 0.085)

    integrity =
      if maintenance >= requirement do
        min(1.0, state.integrity + 0.006 * (maintenance / requirement))
      else
        max(0.0, state.integrity - 0.035 * ((requirement - maintenance) / requirement))
      end

    persisted = integrity > Keyword.get(opts, :failure_threshold, 0.12)

    snapshot = %{
      tick: tick,
      intake: intake,
      maintenance: maintenance,
      action: action,
      store: max(0.0, available - spent),
      integrity: integrity,
      persisted: persisted
    }

    %State{
      state
      | tick: tick,
        store: snapshot.store,
        integrity: integrity,
        persisted: persisted,
        total_intake: state.total_intake + intake,
        maintenance_used: state.maintenance_used + maintenance,
        action_used: state.action_used + action,
        unresolved: state.unresolved + result.unresolved,
        history: [snapshot | state.history]
    }
  end

  defp format(value), do: :erlang.float_to_binary(value * 1.0, decimals: 3)
end
