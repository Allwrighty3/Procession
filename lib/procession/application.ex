defmodule Procession.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Procession.EntityRegistry},
      {Procession.EntitySupervisor, []}
    ]

    opts = [strategy: :one_for_one, name: Procession.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
