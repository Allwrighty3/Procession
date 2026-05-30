defmodule Mix.Tasks.Procession.Play do
  @moduledoc """
  Starts the tiny local Procession CLI demo.
  """

  use Mix.Task

  @shortdoc "Starts the local Procession CLI demo"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    Procession.CLI.play()
  end
end
