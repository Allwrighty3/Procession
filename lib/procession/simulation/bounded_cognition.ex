defmodule Procession.Simulation.BoundedCognition do
  @moduledoc """
  Runs thought as a bounded sequence of positive-cost internal actions.

  The caller owns memory, candidate generation, prediction and decision semantics.
  This module only enforces cognitive work limits, preserves unfinished thought across
  ticks, and records whether internal work changed the eventual physical choice.
  """

  @enforce_keys [:continuation]
  defstruct continuation: nil,
            intended_action: nil,
            baseline_action: nil,
            trace: [],
            total_work: 0,
            last_tick_work: 0,
            last_tick_operations: 0,
            decision_influence: 0

  @type operation_kind :: :recall | :project | :compare
  @type operation :: {operation_kind(), pos_integer(), term()}
  @type decision :: {:commit, term(), term()} | {:continue, operation(), term()} | {:stop, term()}
  @type t :: %__MODULE__{}

  @spec new(term(), keyword()) :: t()
  def new(continuation \\ nil, opts \\ []) do
    %__MODULE__{
      continuation: continuation,
      baseline_action: Keyword.get(opts, :baseline_action)
    }
  end

  @doc """
  Executes at most the supplied cognitive work budget for one external tick.

  `step_fun` receives the current continuation and remaining budget and must return:

    * `{:continue, {kind, positive_cost, detail}, continuation}`
    * `{:commit, physical_action, continuation}`
    * `{:stop, continuation}`

  Unfinished continuation is retained for the next tick. A secondary operation cap
  protects against malformed zero-progress callers even though every accepted
  operation must have a positive integer cost.
  """
  @spec run_tick(t(), (term(), non_neg_integer() -> decision()), keyword()) :: t()
  def run_tick(%__MODULE__{} = state, step_fun, opts \\ []) when is_function(step_fun, 2) do
    budget = Keyword.get(opts, :cognitive_budget, 32)
    max_operations = Keyword.get(opts, :max_operations, budget)

    unless is_integer(budget) and budget >= 0 do
      raise ArgumentError, "cognitive_budget must be a non-negative integer"
    end

    unless is_integer(max_operations) and max_operations >= 0 do
      raise ArgumentError, "max_operations must be a non-negative integer"
    end

    state = %{state | last_tick_work: 0, last_tick_operations: 0, trace: []}
    reduce_tick(state, step_fun, budget, max_operations)
  end

  defp reduce_tick(state, _step_fun, remaining, operations_left)
       when remaining <= 0 or operations_left <= 0,
       do: state

  defp reduce_tick(state, step_fun, remaining, operations_left) do
    case step_fun.(state.continuation, remaining) do
      {:stop, continuation} ->
        %{state | continuation: continuation}

      {:commit, action, continuation} ->
        influenced =
          if is_nil(state.baseline_action) or action == state.baseline_action,
            do: state.decision_influence,
            else: state.decision_influence + 1

        %{state |
          continuation: continuation,
          intended_action: action,
          decision_influence: influenced}

      {:continue, {kind, cost, detail}, continuation}
      when kind in [:recall, :project, :compare] and is_integer(cost) and cost > 0 ->
        if cost > remaining do
          state
        else
          next = %{state |
            continuation: continuation,
            trace: [{kind, cost, detail} | state.trace],
            total_work: state.total_work + cost,
            last_tick_work: state.last_tick_work + cost,
            last_tick_operations: state.last_tick_operations + 1}

          reduce_tick(next, step_fun, remaining - cost, operations_left - 1)
        end

      {:continue, {_kind, cost, _detail}, _continuation} ->
        raise ArgumentError, "thought operations must use a known kind and positive integer cost, got: #{inspect(cost)}"

      other ->
        raise ArgumentError, "invalid cognitive step result: #{inspect(other)}"
    end
  end
end
