defmodule Procession.Simulation.LiveSocialPlane do
  use GenServer

  @moduledoc """
  OTP owner for observation-derived social and institutional relations.

  The process owns directed relational history, not entity minds or physical truth.
  Callers provide only observers that had a grounded opportunity to perceive an event.
  """

  alias Procession.Simulation.SocialRelationPlane

  @name __MODULE__

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    plane_opts = Keyword.get(opts, :plane_opts, [])
    GenServer.start_link(__MODULE__, plane_opts, name: name)
  end

  def observe(observer_id, event, tick), do: observe(@name, observer_id, event, tick, [])
  def observe(observer_id, event, tick, opts), do: observe(@name, observer_id, event, tick, opts)

  def observe(server, observer_id, event, tick, opts) do
    GenServer.call(server, {:observe, observer_id, event, tick, opts})
  end

  def advance(tick), do: advance(@name, tick, [])
  def advance(tick, opts), do: advance(@name, tick, opts)
  def advance(server, tick, opts), do: GenServer.call(server, {:advance, tick, opts})

  def trace(server \\ @name), do: GenServer.call(server, :trace)
  def state(server \\ @name), do: GenServer.call(server, :state)

  def running?(server \\ @name) do
    case server do
      pid when is_pid(pid) -> Process.alive?(pid)
      atom when is_atom(atom) -> not is_nil(Process.whereis(atom))
      _ -> false
    end
  end

  @impl true
  def init(plane_opts), do: {:ok, SocialRelationPlane.new(plane_opts)}

  @impl true
  def handle_call({:observe, observer_id, event, tick, opts}, _from, state) do
    {updated, signals} = SocialRelationPlane.observe(state, observer_id, event, tick, opts)
    {:reply, {:ok, signals, SocialRelationPlane.trace(updated)}, updated}
  end

  def handle_call({:advance, tick, opts}, _from, state) do
    updated = SocialRelationPlane.advance(state, tick, opts)
    {:reply, {:ok, SocialRelationPlane.trace(updated)}, updated}
  end

  def handle_call(:trace, _from, state), do: {:reply, SocialRelationPlane.trace(state), state}
  def handle_call(:state, _from, state), do: {:reply, state, state}
end
