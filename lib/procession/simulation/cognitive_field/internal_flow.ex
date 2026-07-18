defmodule Procession.Simulation.CognitiveField.InternalFlow do
  @moduledoc """
  Weak, finite local propagation that leaves proportionally smaller residue.

  Internal flow uses the same local propagation substrate as enacted activity.
  It differs only in energy, reach, exit requirements, and learning strength.
  """

  alias Procession.Simulation.CognitiveField
  alias Procession.Simulation.CognitiveField.FlowLearning
  alias Procession.Simulation.CognitiveField.LocalFlow

  @type rehearsal :: %{
          field: CognitiveField.t(),
          result: LocalFlow.Result.t()
        }

  @spec rehearse(CognitiveField.t(), map(), MapSet.t() | [term()], keyword()) :: rehearsal()
  def rehearse(%CognitiveField{} = field, activation, exits, opts \\ []) do
    flow_opts =
      opts
      |> Keyword.put_new(:attenuation, 0.68)
      |> Keyword.put_new(:threshold, 0.025)
      |> Keyword.put_new(:exit_threshold, 0.55)
      |> Keyword.put_new(:max_ticks, 4)

    result = LocalFlow.run(field, activation, exits, flow_opts)

    updated =
      FlowLearning.apply(field, result.flows,
        deposit: Keyword.get(opts, :deposit, 0.012),
        decay_slowing: Keyword.get(opts, :decay_slowing, 0.035),
        decay_scale: Keyword.get(opts, :decay_scale, 0.10)
      )

    %{field: updated, result: result}
  end
end
