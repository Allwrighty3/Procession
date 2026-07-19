defmodule Procession.Simulation.LocalTrace do
  @moduledoc """
  Stores short-lived traces inside one entity.

  A trace records only that a local signal was recently active. It does not
  preserve world provenance or make completed causes queryable from world
  objects. Traces decay unless refreshed and disappear below a threshold.
  """

  @enforce_keys [:signal, :magnitude, :age]
  defstruct [:signal, :magnitude, :age]

  @type signal :: term()
  @type t :: %__MODULE__{signal: signal(), magnitude: float(), age: non_neg_integer()}
  @type traces :: %{optional(signal()) => t()}

  @spec new() :: traces()
  def new, do: %{}

  @spec activate(traces(), signal(), number(), keyword()) :: traces()
  def activate(traces, signal, magnitude, opts \\ [])
      when is_map(traces) and is_number(magnitude) do
    maximum = Keyword.get(opts, :maximum, 1.0)
    previous = Map.get(traces, signal, %__MODULE__{signal: signal, magnitude: 0.0, age: 0})

    Map.put(traces, signal, %__MODULE__{
      signal: signal,
      magnitude: min(maximum, previous.magnitude + max(0.0, magnitude * 1.0)),
      age: 0
    })
  end

  @spec decay(traces(), keyword()) :: traces()
  def decay(traces, opts \\ []) when is_map(traces) do
    factor = Keyword.get(opts, :factor, 0.55)
    threshold = Keyword.get(opts, :threshold, 0.01)

    Enum.reduce(traces, %{}, fn {signal, trace}, acc ->
      magnitude = trace.magnitude * factor

      if magnitude >= threshold do
        Map.put(acc, signal, %{trace | magnitude: magnitude, age: trace.age + 1})
      else
        acc
      end
    end)
  end

  @spec magnitude(traces(), signal()) :: float()
  def magnitude(traces, signal) when is_map(traces) do
    case Map.get(traces, signal) do
      nil -> 0.0
      trace -> trace.magnitude
    end
  end

  @spec overlap(traces(), [signal()]) :: float()
  def overlap(traces, signals) when is_map(traces) and is_list(signals) do
    signals
    |> Enum.map(&magnitude(traces, &1))
    |> Enum.min(fn -> 0.0 end)
  end
end
