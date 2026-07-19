defmodule Procession.Simulation.TerrainRelaxer do
  @moduledoc """
  Pure numerical boundary for local relational-terrain settling.

  Elixir owns neighborhood selection, identity, persistence, dimensional policy,
  and simulation timing. A relaxer receives only a small local numeric problem
  and returns adjusted coordinates plus residual metrics. This boundary is
  intentionally suitable for a later native implementation.
  """

  @type region_id :: term()
  @type vector :: [float()]

  @type constraint :: %{
          required(:source) => region_id(),
          required(:target) => region_id(),
          required(:distance) => float(),
          required(:weight) => float()
        }

  @type problem :: %{
          required(:coordinates) => %{region_id() => vector()},
          required(:constraints) => [constraint()],
          optional(:fixed) => MapSet.t(region_id())
        }

  @type result :: %{
          required(:coordinates) => %{region_id() => vector()},
          required(:residual) => float(),
          required(:iterations) => non_neg_integer()
        }

  @callback relax(problem(), keyword()) :: result()
end
