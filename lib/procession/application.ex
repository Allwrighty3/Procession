defmodule Procession.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Procession.EntityRegistry},
      {Registry, keys: :unique, name: Procession.Simulation.InternalFieldRegistry},
      {DynamicSupervisor,
       strategy: :one_for_one, name: Procession.Simulation.InternalFieldSupervisor},
      {Procession.EntitySupervisor, []},
      {Procession.Simulation.LiveResolutionManager, []},
      {Procession.Simulation.RegionActivationLifecycle, []},
      {Procession.Simulation.CoarseTravel, []},
      {Procession.Simulation.AutomaticResolutionPolicy, []},
      {Procession.Simulation.RegionObservationPublisher, []},
      {Procession.WorldClock,
       [coarse_travel: true, resolution_policy: true, region_observations: true]}
    ]

    opts = [strategy: :one_for_one, name: Procession.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
