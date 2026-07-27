defmodule Procession.Simulation.CognitiveMaterialKernel do
  @moduledoc """
  Pure physical state for material consequences initiated by dormant motor output.

  World time replenishes loose raw material independently. Gathering, transformation,
  consumption, contact transfer, and region crossing happen only when explicitly applied.
  """

  def new(opts \\ []) do
    residents =
      opts
      |> Keyword.get(:residents, [])
      |> Map.new(fn attrs ->
        id = Map.fetch!(attrs, :id)

        {id,
         %{
           id: id,
           position: Map.get(attrs, :position, {0, 0}),
           raw: non_negative(Map.get(attrs, :raw, 0.0)),
           usable: non_negative(Map.get(attrs, :usable, 0.0)),
           energy: clamp(Map.get(attrs, :energy, 0.6), 0.0, 1.0),
           capacity: non_negative(Map.get(attrs, :capacity, 0.6)),
           gather_rate: non_negative(Map.get(attrs, :gather_rate, 0.04)),
           transform_rate: non_negative(Map.get(attrs, :transform_rate, 0.03)),
           consume_rate: non_negative(Map.get(attrs, :consume_rate, 0.025)),
           transfer_rate: non_negative(Map.get(attrs, :transfer_rate, 0.02))
         }}
      end)

    %{
      loose_raw: non_negative(Keyword.get(opts, :loose_raw, 1.0)),
      replenishment: non_negative(Keyword.get(opts, :replenishment, 0.0)),
      contact_radius: max(0, Keyword.get(opts, :contact_radius, 1)),
      residents: residents,
      consumed_total: 0.0,
      events: []
    }
  end

  def begin_tick(state), do: %{state | loose_raw: state.loose_raw + state.replenishment, events: []}

  def pressure(state) do
    count = max(map_size(state.residents), 1)
    usable = held(state, :usable) / count

    deficit =
      state.residents
      |> Map.values()
      |> Enum.map(fn resident -> 1.0 - resident.energy end)
      |> Enum.sum()
      |> Kernel./(count)

    clamp(deficit + max(0.0, 0.18 - usable) * 2.0, 0.0, 1.5)
  end

  def contacts(state, identity_id) do
    resident = Map.fetch!(state.residents, identity_id)

    state.residents
    |> Map.values()
    |> Enum.reject(&(&1.id == identity_id))
    |> Enum.flat_map(fn other ->
      distance = distance(resident.position, other.position)

      if distance <= max(3, state.contact_radius) do
        [
          %{
            identity_id: other.id,
            distance: distance,
            direction: relative_direction(resident.position, other.position)
          }
        ]
      else
        []
      end
    end)
    |> Enum.sort_by(&{&1.distance, &1.identity_id})
  end

  def apply(state, identity_id, %{primitive: :contact_loose_raw}) do
    resident = Map.fetch!(state.residents, identity_id)
    room = max(0.0, resident.capacity - resident.raw - resident.usable)
    amount = min(state.loose_raw, min(resident.gather_rate, room))
    resident = %{resident | raw: resident.raw + amount}

    next = %{
      state
      | loose_raw: state.loose_raw - amount,
        residents: Map.put(state.residents, identity_id, resident),
        events: [{:contacted_loose_raw, identity_id, amount} | state.events]
    }

    {next, consequence(:gathered_raw, amount)}
  end

  def apply(state, identity_id, %{primitive: :manipulate_held_raw}) do
    resident = Map.fetch!(state.residents, identity_id)
    amount = min(resident.raw, resident.transform_rate)
    resident = %{resident | raw: resident.raw - amount, usable: resident.usable + amount}

    next = %{
      state
      | residents: Map.put(state.residents, identity_id, resident),
        events: [{:manipulated_held_raw, identity_id, amount} | state.events]
    }

    {next, consequence(:transformed_material, amount)}
  end

  def apply(state, identity_id, %{primitive: :consume_held_usable}) do
    resident = Map.fetch!(state.residents, identity_id)
    demand = resident.consume_rate + max(0.0, 0.5 - resident.energy) * 0.03
    amount = min(resident.usable, demand)
    energy = clamp(resident.energy - 0.012 + amount * 1.8, 0.0, 1.0)
    resident = %{resident | usable: resident.usable - amount, energy: energy}

    next = %{
      state
      | residents: Map.put(state.residents, identity_id, resident),
        consumed_total: state.consumed_total + amount,
        events: [{:consumed_held_usable, identity_id, amount} | state.events]
    }

    {next, consequence(:consumed_usable, amount, energy - Map.fetch!(state.residents, identity_id).energy)}
  end

  def apply(state, identity_id, %{primitive: :contact_body, counterparty_id: counterparty_id}) do
    source = Map.fetch!(state.residents, identity_id)
    recipient = Map.fetch!(state.residents, counterparty_id)

    if distance(source.position, recipient.position) <= state.contact_radius do
      room = max(0.0, recipient.capacity - recipient.raw - recipient.usable)
      amount = min(source.transfer_rate, min(source.usable, room))
      source = %{source | usable: source.usable - amount}
      recipient = %{recipient | usable: recipient.usable + amount}

      residents =
        state.residents
        |> Map.put(identity_id, source)
        |> Map.put(counterparty_id, recipient)

      next = %{
        state
        | residents: residents,
          events: [{:contacted_body, identity_id, counterparty_id, amount} | state.events]
      }

      {next, consequence(:transferred_usable, amount)}
    else
      {state, consequence(:body_out_of_contact, 0.0)}
    end
  end

  def apply(state, _identity_id, _action), do: {state, consequence(:no_effect, 0.0)}

  def remove_resident(state, identity_id) do
    {Map.fetch!(state.residents, identity_id), %{state | residents: Map.delete(state.residents, identity_id)}}
  end

  def put_resident(state, resident), do: %{state | residents: Map.put(state.residents, resident.id, resident)}

  def total_material(state),
    do: state.loose_raw + held(state, :raw) + held(state, :usable) + state.consumed_total

  defp consequence(kind, amount, energy_delta \\ 0.0) do
    %{
      kind: kind,
      amount: amount,
      coherence: if(amount > 0.0 or energy_delta > 0.0, do: 0.4, else: -0.05),
      features: [
        {:signal, {:material_consequence, kind}, max(0.1, min(1.5, amount * 10.0))},
        {:signal, {:body_energy_change, bucket_delta(energy_delta)}, max(0.1, abs(energy_delta) * 10.0)}
      ]
    }
  end

  defp held(state, key),
    do: state.residents |> Map.values() |> Enum.map(&Map.fetch!(&1, key)) |> Enum.sum()

  defp distance({ax, ay}, {bx, by}), do: abs(ax - bx) + abs(ay - by)

  defp relative_direction({ax, ay}, {bx, by}) do
    dx = bx - ax
    dy = by - ay

    cond do
      abs(dx) >= abs(dy) and dx > 0 -> :east
      abs(dx) >= abs(dy) and dx < 0 -> :west
      dy > 0 -> :south
      dy < 0 -> :north
      true -> :none
    end
  end

  defp bucket_delta(value) when value > 0.0001, do: :increased
  defp bucket_delta(value) when value < -0.0001, do: :decreased
  defp bucket_delta(_), do: :unchanged
  defp non_negative(value) when is_number(value), do: max(0.0, value * 1.0)
  defp non_negative(_), do: 0.0
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
end
