defmodule Procession.Simulation.SiblingLearnerProcess do
  @moduledoc """
  OTP-owned learner used by the sibling-development diagnostic.

  The process owns its sensorimotor field and bodily state. The world sends a
  perception tagged with a tick id. Intent calculation happens in the learner's
  mailbox and the result is sent back asynchronously. The world never waits
  indefinitely: a missing intent becomes :wait at the tick boundary.
  """

  use GenServer

  alias Procession.Simulation.DevelopmentalSensorimotorField, as: Field

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  def request_intent(pid, recipient, tick, perception, actions, exploration),
    do: GenServer.cast(pid, {:request_intent, recipient, tick, perception, actions, exploration})

  def commit(pid, action, outcome),
    do: GenServer.call(pid, {:commit, action, outcome}, :infinity)

  def snapshot(pid), do: GenServer.call(pid, :snapshot, :infinity)

  def reset_body(pid, position), do: GenServer.call(pid, {:reset_body, position}, :infinity)

  @impl true
  def init(opts) do
    field_opts = Keyword.fetch!(opts, :field_opts)

    {:ok,
     %{
       id: Keyword.fetch!(opts, :id),
       seed: Keyword.fetch!(opts, :seed),
       field_opts: field_opts,
       field: Field.new(field_opts),
       position: Keyword.get(opts, :position, 0),
       carrying: false,
       hunger: 0.25,
       vitality: 1.0,
       meals: 0,
       first_meal_tick: nil,
       elapsed: 0,
       last_action: nil,
       last_event: :none,
       decisions: 0,
       exploratory_decisions: 0,
       artificial_delay_ms: Keyword.get(opts, :artificial_delay_ms, 0)
     }}
  end

  @impl true
  def handle_cast({:request_intent, recipient, tick, perception, actions, exploration}, state) do
    if state.artificial_delay_ms > 0, do: Process.sleep(state.artificial_delay_ms)

    field = Field.sense(state.field, perception, state.field_opts)
    roll = :erlang.phash2({:explore, state.seed, tick}, 1_000_000) / 1_000_000
    exploratory? = roll < exploration

    action =
      if exploratory? do
        Enum.at(actions, rem(:erlang.phash2({:action, state.seed, tick}), length(actions)))
      else
        scores = Field.output_scores(field, actions, state.field_opts)
        Enum.max_by(actions, fn candidate -> {Map.get(scores, candidate, 0.0), candidate} end)
      end

    send(recipient, {:sibling_intent, tick, state.id, action, exploratory?})

    {:noreply,
     %{
       state
       | field: field,
         decisions: state.decisions + 1,
         exploratory_decisions: state.exploratory_decisions + if(exploratory?, do: 1, else: 0)
     }}
  end

  @impl true
  def handle_call({:reset_body, position}, _from, state) do
    next = %{
      state
      | position: position,
        carrying: false,
        hunger: 0.35,
        vitality: 1.0,
        meals: 0,
        first_meal_tick: nil,
        elapsed: 0,
        last_action: nil,
        last_event: :none
    }

    {:reply, :ok, next}
  end

  def handle_call({:commit, action, outcome}, _from, state) do
    next = apply_outcome(state, action, outcome)
    field = Field.record_output(next.field, action, outcome.coherence, state.field_opts)
    {:reply, :ok, %{next | field: field}}
  end

  def handle_call(:snapshot, _from, state), do: {:reply, public_snapshot(state), state}

  defp apply_outcome(state, action, outcome) do
    elapsed = state.elapsed + 1

    first_meal_tick =
      if outcome.event == :food_consumed and is_nil(state.first_meal_tick),
        do: elapsed,
        else: state.first_meal_tick

    %{
      state
      | position: outcome.position,
        carrying: outcome.carrying,
        hunger: outcome.hunger,
        vitality: outcome.vitality,
        meals: state.meals + if(outcome.event == :food_consumed, do: 1, else: 0),
        first_meal_tick: first_meal_tick,
        elapsed: elapsed,
        last_action: action,
        last_event: outcome.event
    }
  end

  defp public_snapshot(state) do
    Map.take(state, [
      :id,
      :position,
      :carrying,
      :hunger,
      :vitality,
      :meals,
      :first_meal_tick,
      :elapsed,
      :last_action,
      :last_event,
      :decisions,
      :exploratory_decisions
    ])
  end
end
