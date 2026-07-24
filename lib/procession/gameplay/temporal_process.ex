defmodule Procession.TemporalProcess do
  @moduledoc """
  Validated data describing change that occupies world time.

  Temporal processes are inert data. They never contain functions or executable
  generated code. The world clock owns ordering and decides when a process is due.
  """

  @enforce_keys [:id, :kind, :subject_id, :started_at, :next_transition_at]
  defstruct [
    :id,
    :kind,
    :subject_id,
    :started_at,
    :next_transition_at,
    :expected_completion_at,
    :effect,
    state: :in_progress,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          id: term(),
          kind: atom(),
          subject_id: term(),
          started_at: non_neg_integer(),
          next_transition_at: non_neg_integer(),
          expected_completion_at: non_neg_integer() | nil,
          effect: map() | nil,
          state: :in_progress | :completed | :cancelled,
          metadata: map()
        }

  def new(attrs) when is_map(attrs) do
    process = struct(__MODULE__, attrs)

    with :ok <- validate_time(process.started_at, :started_at),
         :ok <- validate_time(process.next_transition_at, :next_transition_at),
         :ok <- validate_order(process),
         :ok <- validate_kind(process.kind),
         :ok <- validate_metadata(process.metadata) do
      {:ok, process}
    end
  rescue
    KeyError -> {:error, :missing_temporal_process_field}
  end

  def new(_attrs), do: {:error, :invalid_temporal_process}

  def due?(%__MODULE__{state: :in_progress, next_transition_at: at}, now), do: at <= now
  def due?(%__MODULE__{}, _now), do: false

  def complete(%__MODULE__{} = process, at) when is_integer(at) and at >= 0 do
    %{process | state: :completed, next_transition_at: at}
  end

  defp validate_time(value, _field) when is_integer(value) and value >= 0, do: :ok
  defp validate_time(_value, field), do: {:error, {:invalid_temporal_process_field, field}}

  defp validate_order(%__MODULE__{started_at: started_at, next_transition_at: next_at})
       when next_at >= started_at,
       do: :ok

  defp validate_order(_process), do: {:error, :temporal_transition_before_start}

  defp validate_kind(kind) when is_atom(kind), do: :ok
  defp validate_kind(_kind), do: {:error, {:invalid_temporal_process_field, :kind}}

  defp validate_metadata(metadata) when is_map(metadata), do: :ok
  defp validate_metadata(_metadata), do: {:error, {:invalid_temporal_process_field, :metadata}}
end
