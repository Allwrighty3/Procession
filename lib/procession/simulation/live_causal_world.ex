defmodule Procession.Simulation.LiveCausalWorld do
  use GenServer

  @moduledoc """
  OTP owner for one active authoritative causal world.

  The world can be ticked directly or discovered by `Procession.WorldClock` when
  registered under its default name. It stores only authoritative world state and
  delegates deterministic transitions to `CausalWorldKernel`.
  """

  alias Procession.Simulation.CausalWorldKernel

  @name __MODULE__

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    kernel_opts = Keyword.get(opts, :kernel_opts, [])
    GenServer.start_link(__MODULE__, kernel_opts, name: name)
  end

  def tick, do: tick(@name, [])
  def tick(server), do: tick(server, [])
  def tick(server, opts), do: GenServer.call(server, {:tick, opts})

  def run(ticks), do: run(@name, ticks, [])
  def run(server, ticks), do: run(server, ticks, [])
  def run(server, ticks, opts), do: GenServer.call(server, {:run, ticks, opts}, :infinity)

  def trace(server \\ @name), do: GenServer.call(server, :trace)
  def state(server \\ @name), do: GenServer.call(server, :state)

  def tick_if_running(opts \\ []) do
    case Process.whereis(@name) do
      nil -> {:ok, %{status: :skipped, reason: :causal_world_not_running}}
      pid -> tick(pid, opts)
    end
  end

  @impl true
  def init(kernel_opts), do: {:ok, CausalWorldKernel.new(kernel_opts)}

  @impl true
  def handle_call({:tick, opts}, _from, state) do
    updated = CausalWorldKernel.tick(state, opts)
    {:reply, {:ok, CausalWorldKernel.trace(updated)}, updated}
  end

  def handle_call({:run, ticks, opts}, _from, state) do
    updated = CausalWorldKernel.run(state, ticks, opts)
    {:reply, {:ok, CausalWorldKernel.trace(updated)}, updated}
  end

  def handle_call(:trace, _from, state), do: {:reply, CausalWorldKernel.trace(state), state}
  def handle_call(:state, _from, state), do: {:reply, state, state}
end
