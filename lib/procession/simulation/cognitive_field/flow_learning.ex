defmodule Procession.Simulation.CognitiveField.FlowLearning do
  @moduledoc """
  Applies residue updates in proportion to observed local activation flow.

  This module treats flow records as diagnostics of actual traversal. It does
  not choose routes, exits, goals, or meanings.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.Transition

  @type edge :: {term(), term()}
  @type flows :: %{optional(edge()) => number()}

  @spec apply(CognitiveField.t(), flows(), keyword()) :: CognitiveField.t()
  def apply(%CognitiveField{} = field, flows, opts \\ []) when is_map(flows) do
    deposit = Keyword.get(opts, :deposit, 0.09)
    decay_slowing = Keyword.get(opts, :decay_slowing, 0.13)
    decay_scale = Keyword.get(opts, :decay_scale, 1.0)
    maximum_flow = flows |> Map.values() |> Enum.max(fn -> 0.0 end)

    transitions =
      Map.new(field.transitions, fn {edge, transition} ->
        elapsed_decay = min(1.0, transition.decay * decay_scale)
        decayed_residue = transition.residue * (1.0 - elapsed_decay)
        normalized_flow = normalized_flow(flows, edge, maximum_flow)

        updated =
          if normalized_flow > 0.0 do
            %Transition{
              transition
              | residue: min(1.0, decayed_residue + deposit * normalized_flow),
                decay:
                  max(
                    transition.minimum_decay,
                    transition.decay * (1.0 - decay_slowing * normalized_flow)
                  )
            }
          else
            %Transition{
              transition
              | residue: decayed_residue,
                decay:
                  min(
                    transition.baseline_decay,
                    transition.decay + 0.0008 * decay_scale
                  )
            }
          end

        {edge, updated}
      end)

    %{field | transitions: transitions, tick: field.tick + 1}
  end

  defp normalized_flow(_flows, _edge, maximum_flow) when maximum_flow <= 0.0, do: 0.0

  defp normalized_flow(flows, edge, maximum_flow) do
    Map.get(flows, edge, 0.0) / maximum_flow
  end
end
