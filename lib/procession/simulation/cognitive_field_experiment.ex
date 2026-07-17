defmodule Procession.Simulation.CognitiveFieldExperiment do
  @moduledoc """
  Closed-loop experiment runner for `Procession.Simulation.CognitiveField`.

  This module owns experiment meaning. The field receives temporary activation,
  chooses an exit, and is then changed by the world's continuation. The field
  itself never knows which exit is correct.
  """

  alias Procession.Simulation.CognitiveField
  alias CognitiveField.Trajectory

  @type continuation ::
          :coherent
          | :neutral
          | {:contradiction, keyword()}

  @type episode_result :: %{
          field: CognitiveField.t(),
          trajectory: Trajectory.t(),
          continuation: continuation()
        }

  @spec run_episode(
          CognitiveField.t(),
          term(),
          [term()],
          (Trajectory.t() -> continuation()),
          keyword()
        ) :: {:ok, episode_result()} | {:error, :unreachable | :no_exits}
  def run_episode(field, entry, exits, continuation_fun, opts \\ [])
      when is_function(continuation_fun, 1) do
    propagation_opts =
      opts
      |> Keyword.take([:activation, :activation_bias, :temperature, :seed])
      |> Keyword.put(:exits, exits)

    with {:ok, trajectory} <- CognitiveField.propagate(field, entry, propagation_opts) do
      continuation = continuation_fun.(trajectory)
      next_field = apply_continuation(field, trajectory, continuation, opts)

      {:ok,
       %{
         field: next_field,
         trajectory: trajectory,
         continuation: continuation
       }}
    end
  end

  @spec run(CognitiveField.t(), [map()], keyword()) ::
          {:ok, %{field: CognitiveField.t(), episodes: [episode_result()]}}
          | {:error, :unreachable | :no_exits}
  def run(field, episodes, opts \\ []) when is_list(episodes) do
    episodes
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, %{field: field, episodes: []}}, fn {episode, index},
                                                                {:ok, state} ->
      episode_opts =
        opts
        |> Keyword.merge(Map.get(episode, :opts, []))
        |> Keyword.put_new(:seed, index)

      case run_episode(
             state.field,
             Map.fetch!(episode, :entry),
             Map.fetch!(episode, :exits),
             Map.fetch!(episode, :continuation),
             episode_opts
           ) do
        {:ok, result} ->
          {:cont,
           {:ok,
            %{
              field: result.field,
              episodes: [result | state.episodes]
            }}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, state} -> {:ok, %{state | episodes: Enum.reverse(state.episodes)}}
      error -> error
    end
  end

  @spec summarize([episode_result()]) :: map()
  def summarize(results) do
    exits = Enum.frequencies_by(results, & &1.trajectory.exit)
    continuations = Enum.frequencies_by(results, &continuation_key(&1.continuation))

    mean_resistance =
      case results do
        [] -> 0.0
        _ -> Enum.sum(Enum.map(results, & &1.trajectory.resistance)) / length(results)
      end

    %{
      episodes: length(results),
      exits: exits,
      continuations: continuations,
      mean_resistance: mean_resistance
    }
  end

  defp apply_continuation(field, trajectory, :coherent, opts) do
    CognitiveField.enact(
      field,
      trajectory,
      deposit: Keyword.get(opts, :coherent_deposit, 0.09)
    )
  end

  defp apply_continuation(field, trajectory, :neutral, opts) do
    CognitiveField.enact(
      field,
      trajectory,
      deposit: Keyword.get(opts, :neutral_deposit, 0.018)
    )
  end

  defp apply_continuation(field, trajectory, {:contradiction, contradiction_opts}, opts) do
    field
    |> CognitiveField.enact(
      trajectory,
      deposit: Keyword.get(opts, :contradicted_deposit, 0.008)
    )
    |> CognitiveField.disturb_terminal(
      trajectory,
      Keyword.merge(
        [magnitude: Keyword.get(opts, :contradiction_magnitude, 0.08)],
        contradiction_opts
      )
    )
  end

  defp continuation_key({:contradiction, _opts}), do: :contradiction
  defp continuation_key(value), do: value
end
