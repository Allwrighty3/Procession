defmodule Procession.Simulation.FlowNetwork.ResponseLaw do
  @moduledoc """
  Contract for domain-specific changes caused by observed flow.

  The flow network transports quantities. A response law decides whether that
  traversal leaves the network unchanged, reinforces it, damages it, repairs it,
  or produces some other domain-specific state transition.
  """

  alias Procession.Simulation.FlowNetwork
  alias Procession.Simulation.FlowNetwork.Result

  @callback apply(FlowNetwork.t(), Result.t(), keyword()) ::
              {FlowNetwork.t(), [map()]}
end

defmodule Procession.Simulation.FlowNetwork.NoChange do
  @moduledoc "A response law that records no structural change."
  @behaviour Procession.Simulation.FlowNetwork.ResponseLaw

  @impl true
  def apply(network, _result, _opts), do: {network, []}
end
