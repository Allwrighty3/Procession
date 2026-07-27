defmodule Procession.Simulation.RegionalMaterialCycle do
  @moduledoc """
  Pure low-level regional material flow.

  Residents gather loose raw material, transform held raw material into usable material,
  consume usable material into bodily recovery, and transfer usable quantity between
  contacting bodies. The cycle stores no occupation, ownership, trade, charity, or social
  interpretation.
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
      residents: residents,
      events: [],
      consumed_total: 0.0
    }
  end

  def step(state) when is_map(state) do
    state = %{state | events: []}
    {state, gathered} = gather(state)
    {state, transformed} = transform(state)
    {state, transferred} = transfer(state)
    {state, consumed} = consume(state)
    state = %{state | loose_raw: state.loose_raw + state.replenishment}

    {state,
     %{
       gathered: gathered,
       transformed: transformed,
       transferred: transferred,
       consumed: consumed,
       loose_raw: state.loose_raw,
       held_raw: held(state, :raw),
       held_usable: held(state, :usable),
       mean_energy: mean_energy(state),
       events: Enum.reverse(state.events)
     }}
  end

  def total_material(state) do
    state.loose_raw + held(state, :raw) + held(state, :usable) + state.consumed_total
  end

  def pressure(state) do
    count = max(map_size(state.residents), 1)
    usable = held(state, :usable) / count

    energy_deficit =
      state.residents
      |> Map.values()
      |> Enum.map(fn resident -> 1.0 - resident.energy end)
      |> Enum.sum()
      |> Kernel./(count)

    clamp(energy_deficit + max(0.0, 0.18 - usable) * 2.0, 0.0, 1.5)
  end

  defp gather(state) do
    Enum.reduce(sorted_ids(state), {state, 0.0}, fn id, {current, total} ->
      resident = current.residents[id]
      room = max(0.0, resident.capacity - resident.raw - resident.usable)
      amount = min(current.loose_raw, min(resident.gather_rate, room))
      updated = %{resident | raw: resident.raw + amount}

      next = %{
        current
        | loose_raw: current.loose_raw - amount,
          residents: Map.put(current.residents, id, updated),
          events: [{:gathered_raw, id, amount} | current.events]
      }

      {next, total + amount}
    end)
  end

  defp transform(state) do
    Enum.reduce(sorted_ids(state), {state, 0.0}, fn id, {current, total} ->
      resident = current.residents[id]
      amount = min(resident.raw, resident.transform_rate)
      updated = %{resident | raw: resident.raw - amount, usable: resident.usable + amount}

      next = %{
        current
        | residents: Map.put(current.residents, id, updated),
          events: [{:transformed_material, id, amount} | current.events]
      }

      {next, total + amount}
    end)
  end

  defp transfer(state) do
    recipients =
      state
      |> sorted_ids()
      |> Enum.sort_by(fn id -> {state.residents[id].energy, id} end)

    Enum.reduce(recipients, {state, 0.0}, fn recipient_id, {current, total} ->
      recipient = current.residents[recipient_id]

      donors =
        current
        |> sorted_ids()
        |> Enum.reject(fn id -> id == recipient_id end)
        |> Enum.filter(fn id -> current.residents[id].usable > 0.08 end)

      donor_id =
        case donors do
          [] -> nil
          _ -> Enum.max_by(donors, fn id -> current.residents[id].usable end)
        end

      maybe_transfer(current, total, donor_id, recipient_id, recipient)
    end)
  end

  defp maybe_transfer(current, total, nil, _recipient_id, _recipient), do: {current, total}

  defp maybe_transfer(current, total, donor_id, recipient_id, recipient) do
    if recipient.energy < 0.45 do
      donor = current.residents[donor_id]
      room = max(0.0, recipient.capacity - recipient.raw - recipient.usable)
      amount = min(donor.transfer_rate, min(donor.usable - 0.08, room))

      if amount > 0.0 do
        donor = %{donor | usable: donor.usable - amount}
        recipient = %{recipient | usable: recipient.usable + amount}

        residents =
          current.residents
          |> Map.put(donor_id, donor)
          |> Map.put(recipient_id, recipient)

        next = %{
          current
          | residents: residents,
            events: [{:transferred_usable, donor_id, recipient_id, amount} | current.events]
        }

        {next, total + amount}
      else
        {current, total}
      end
    else
      {current, total}
    end
  end

  defp consume(state) do
    Enum.reduce(sorted_ids(state), {state, 0.0}, fn id, {current, total} ->
      resident = current.residents[id]
      demand = resident.consume_rate + max(0.0, 0.5 - resident.energy) * 0.03
      amount = min(resident.usable, demand)
      energy = clamp(resident.energy - 0.012 + amount * 1.8, 0.0, 1.0)
      updated = %{resident | usable: resident.usable - amount, energy: energy}

      next = %{
        current
        | residents: Map.put(current.residents, id, updated),
          consumed_total: current.consumed_total + amount,
          events: [{:consumed_usable, id, amount} | current.events]
      }

      {next, total + amount}
    end)
  end

  defp held(state, key) do
    state.residents
    |> Map.values()
    |> Enum.map(fn resident -> Map.fetch!(resident, key) end)
    |> Enum.sum()
  end

  defp mean_energy(state) do
    state.residents
    |> Map.values()
    |> Enum.map(fn resident -> resident.energy end)
    |> average()
  end

  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)
  defp sorted_ids(state), do: state.residents |> Map.keys() |> Enum.sort()
  defp non_negative(value) when is_number(value), do: max(0.0, value * 1.0)
  defp non_negative(_value), do: 0.0
  defp clamp(value, low, high), do: value |> max(low) |> min(high)
end
