defmodule Procession.Simulation.RelationalTerrain do
  @moduledoc """
  Experimental sparse manifold-style developmental field.

  Three-dimensional terrain is only a human interpretation aid. Internally, regions
  occupy an arbitrary-dimensional relational space, including a viable one-dimensional
  space. New regions are placed relative to the currently experienced neighborhood;
  persistent memory is deformation of local geometry, and transient activity flows
  through only the active neighborhood. Dimensions may expand when distinct local
  relationships cannot be represented without collision or excessive directional
  crowding in the current manifold.
  """

  defmodule Region do
    @moduledoc false
    defstruct [:id, :center, :visits, :depth, geometry: %{}]
  end

  defmodule State do
    @moduledoc false
    defstruct dimensions: 1,
              dimension_expansions: 0,
              next_id: 0,
              regions: %{},
              label_index: %{},
              activity: %{},
              active_region_ids: MapSet.new(),
              last_observed_region: nil,
              tick: 0
  end

  @type vector :: [float()]

  def new(opts \\ []) do
    dimensions = Keyword.get(opts, :dimensions, 1)

    if not is_integer(dimensions) or dimensions < 1 do
      raise ArgumentError, "dimensions must be a positive integer"
    end

    %State{dimensions: dimensions}
  end

  def observe(%State{} = state, observation, opts \\ []) do
    initial_proposal = contextual_proposal(state, observation, opts)
    {state, proposal} = maybe_expand_for_conflict(state, observation, initial_proposal, opts)
    {state, region_id} = locate_or_create(state, observation, proposal, opts)
    state = adapt_region_center(state, region_id, proposal, opts)
    state = deform_from_previous(state, region_id, opts)

    activity =
      state.activity
      |> decay_activity(opts)
      |> Map.update(region_id, 1.0, &min(&1 + 1.0, 3.0))

    %{state |
      tick: state.tick + 1,
      activity: activity,
      active_region_ids: active_ids(activity, opts),
      last_observed_region: region_id,
      regions: update_visit(state.regions, region_id, opts)
    }
  end

  def advance(%State{} = state, opts \\ []) do
    retained = decay_activity(state.activity, opts)
    propagated = propagate(state.activity, state.regions, opts)
    activity = merge_activity(retained, propagated, opts)

    %{state |
      tick: state.tick + 1,
      activity: activity,
      active_region_ids: active_ids(activity, opts),
      last_observed_region: nil
    }
  end

  def clear_activity(%State{} = state) do
    %{state | activity: %{}, active_region_ids: MapSet.new(), last_observed_region: nil}
  end

  def activation(%State{} = state, observation) do
    case Map.get(state.label_index, observation) do
      nil -> 0.0
      region_id -> Map.get(state.activity, region_id, 0.0)
    end
  end

  def region_count(%State{} = state), do: map_size(state.regions)
  def active_region_count(%State{} = state), do: MapSet.size(state.active_region_ids)
  def dimension_count(%State{} = state), do: state.dimensions
  def dimension_expansion_count(%State{} = state), do: state.dimension_expansions

  def local_region(%State{} = state, observation) do
    with region_id when not is_nil(region_id) <- Map.get(state.label_index, observation) do
      Map.get(state.regions, region_id)
    end
  end

  def deformation(%State{} = state, from, to) do
    with from_id when not is_nil(from_id) <- Map.get(state.label_index, from),
         to_id when not is_nil(to_id) <- Map.get(state.label_index, to),
         %Region{} = region <- Map.get(state.regions, from_id) do
      Map.get(region.geometry, to_id, 0.0)
    else
      _ -> 0.0
    end
  end

  defp contextual_proposal(%State{last_observed_region: nil, dimensions: dimensions}, _observation, _opts),
    do: List.duplicate(0.0, dimensions)

  defp contextual_proposal(state, observation, opts) do
    case Map.get(state.label_index, observation) do
      nil ->
        previous = Map.fetch!(state.regions, state.last_observed_region)
        step = Keyword.get(opts, :placement_step, 0.35)
        direction = placement_direction(state, previous, observation, opts)
        add(previous.center, scale(direction, step))

      region_id ->
        Map.fetch!(state.regions, region_id).center
    end
  end

  defp placement_direction(%State{dimensions: 1} = state, previous, observation, opts) do
    occupied =
      previous.geometry
      |> Map.keys()
      |> Enum.map(fn id -> Map.fetch!(state.regions, id).center end)
      |> Enum.map(fn [coordinate] -> coordinate - hd(previous.center) end)
      |> Enum.reject(&(&1 == 0.0))
      |> Enum.map(&if(&1 < 0.0, do: -1.0, else: 1.0))
      |> Enum.uniq()

    case occupied do
      [side] -> [-side]
      _ -> innovation_direction(observation, 1, opts)
    end
  end

  defp placement_direction(state, _previous, observation, opts),
    do: innovation_direction(observation, state.dimensions, opts)

  defp innovation_direction(observation, dimensions, opts) do
    case Keyword.get(opts, :direction_provider) do
      provider when is_function(provider, 2) ->
        provider.(observation, dimensions)
        |> fit_dimensions(dimensions)
        |> normalize()
        |> ensure_direction()

      _ ->
        salt = Keyword.get(opts, :encoding_salt, :relational_terrain)

        0..(dimensions - 1)
        |> Enum.map(fn dimension ->
          (:erlang.phash2({salt, observation, dimension}, 2_000_001) - 1_000_000) / 1_000_000
        end)
        |> normalize()
        |> ensure_direction()
    end
  end

  defp fit_dimensions(vector, dimensions) when is_list(vector) do
    vector
    |> Enum.take(dimensions)
    |> Kernel.++(List.duplicate(0.0, max(dimensions - length(vector), 0)))
  end

  defp ensure_direction(vector) do
    if Enum.all?(vector, &(&1 == 0.0)) do
      [1.0 | List.duplicate(0.0, max(length(vector) - 1, 0))]
    else
      vector
    end
  end

  defp maybe_expand_for_conflict(state, observation, proposal, opts) do
    cond do
      Map.has_key?(state.label_index, observation) ->
        {state, proposal}

      is_nil(state.last_observed_region) ->
        {state, proposal}

      not Keyword.get(opts, :auto_expand_dimensions, true) ->
        {state, proposal}

      state.dimensions >= Keyword.get(opts, :max_dimensions, 64) ->
        {state, proposal}

      local_distortion?(state, proposal, opts) ->
        expand_dimension(state, observation, opts)

      true ->
        {state, proposal}
    end
  end

  defp local_distortion?(state, proposal, opts) do
    local_collision?(state, proposal, opts) or local_direction_crowding?(state, proposal, opts)
  end

  defp local_collision?(state, proposal, opts) do
    source = Map.fetch!(state.regions, state.last_observed_region)
    threshold = Keyword.get(opts, :dimension_conflict_radius, Keyword.get(opts, :reuse_radius, 0.08) * 1.5)

    Enum.any?(Map.keys(source.geometry), fn target_id ->
      target = Map.fetch!(state.regions, target_id)
      distance(proposal, target.center) <= threshold
    end)
  end

  defp local_direction_crowding?(%State{dimensions: 1}, _proposal, _opts), do: false

  defp local_direction_crowding?(state, proposal, opts) do
    source = Map.fetch!(state.regions, state.last_observed_region)
    proposed_direction = subtract(proposal, source.center) |> normalize()
    cosine_limit = Keyword.get(opts, :direction_crowding_cosine, 0.965)
    minimum_neighbors = Keyword.get(opts, :direction_crowding_min_neighbors, 1)

    existing_directions =
      source.geometry
      |> Map.keys()
      |> Enum.map(fn target_id ->
        target = Map.fetch!(state.regions, target_id)
        subtract(target.center, source.center) |> normalize()
      end)
      |> Enum.reject(&zero_vector?/1)

    length(existing_directions) >= minimum_neighbors and
      Enum.any?(existing_directions, fn direction -> dot(proposed_direction, direction) >= cosine_limit end)
  end

  defp expand_dimension(state, observation, opts) do
    expanded_regions =
      Map.new(state.regions, fn {id, region} ->
        {id, %{region | center: region.center ++ [0.0]}}
      end)

    expanded = %{state |
      dimensions: state.dimensions + 1,
      dimension_expansions: state.dimension_expansions + 1,
      regions: expanded_regions
    }

    previous = Map.fetch!(expanded.regions, expanded.last_observed_region)
    step = Keyword.get(opts, :placement_step, 0.35)
    sign = expansion_sign(observation, expanded.dimensions, opts)
    proposal = add(previous.center, List.duplicate(0.0, expanded.dimensions - 1) ++ [step * sign])
    {expanded, proposal}
  end

  defp expansion_sign(observation, dimensions, opts) do
    salt = Keyword.get(opts, :encoding_salt, :relational_terrain)
    if :erlang.phash2({salt, observation, dimensions, :expansion}, 2) == 0, do: -1.0, else: 1.0
  end

  defp locate_or_create(state, observation, proposal, opts) do
    case Map.get(state.label_index, observation) do
      nil ->
        radius = Keyword.get(opts, :reuse_radius, 0.08)

        nearest =
          state.regions
          |> Enum.map(fn {id, region} -> {id, distance(proposal, region.center)} end)
          |> Enum.min_by(&elem(&1, 1), fn -> nil end)

        case nearest do
          {id, separation} when separation <= radius ->
            {%{state | label_index: Map.put(state.label_index, observation, id)}, id}

          _ ->
            id = state.next_id
            region = %Region{id: id, center: proposal, visits: 0, depth: 0.0}

            {%{state |
               next_id: id + 1,
               regions: Map.put(state.regions, id, region),
               label_index: Map.put(state.label_index, observation, id)
             }, id}
        end

      id ->
        {state, id}
    end
  end

  defp adapt_region_center(state, id, proposal, opts) do
    rate = Keyword.get(opts, :placement_learning_rate, 0.04)

    regions =
      Map.update!(state.regions, id, fn region ->
        center = interpolate(region.center, proposal, rate)
        %{region | center: center}
      end)

    %{state | regions: regions}
  end

  defp deform_from_previous(%State{last_observed_region: nil} = state, _current, _opts), do: state
  defp deform_from_previous(%State{last_observed_region: current} = state, current, _opts), do: state

  defp deform_from_previous(state, current, opts) do
    previous = state.last_observed_region
    amount = Keyword.get(opts, :deformation_rate, 0.12)
    reverse_ratio = Keyword.get(opts, :reverse_deformation_ratio, 0.10)

    regions =
      state.regions
      |> deepen(previous, current, amount)
      |> deepen(current, previous, amount * reverse_ratio)

    %{state | regions: regions}
  end

  defp deepen(regions, source, target, amount) do
    Map.update!(regions, source, fn region ->
      geometry = Map.update(region.geometry, target, amount, &(&1 + amount))
      %{region | geometry: geometry, depth: region.depth + amount}
    end)
  end

  defp update_visit(regions, id, opts) do
    center_rate = Keyword.get(opts, :center_learning_rate, 0.02)

    Map.update!(regions, id, fn region ->
      %{region | visits: region.visits + 1, depth: region.depth + center_rate}
    end)
  end

  defp propagate(activity, regions, opts) do
    flow_fraction = Keyword.get(opts, :flow_fraction, 0.82)
    flow_floor = Keyword.get(opts, :flow_floor, 0.01)

    Enum.reduce(activity, %{}, fn {source, source_activity}, acc ->
      geometry = Map.fetch!(regions, source).geometry
      total = Enum.sum(Map.values(geometry))

      if total <= 0.0 do
        acc
      else
        Enum.reduce(geometry, acc, fn {target, deformation}, flow_acc ->
          amount = source_activity * flow_fraction * deformation / total
          if amount < flow_floor, do: flow_acc, else: Map.update(flow_acc, target, amount, &(&1 + amount))
        end)
      end
    end)
  end

  defp merge_activity(retained, propagated, opts) do
    cap = Keyword.get(opts, :activity_cap, 3.0)
    Map.merge(retained, propagated, fn _id, left, right -> min(cap, left + right) end)
  end

  defp decay_activity(activity, opts) do
    retention = Keyword.get(opts, :activity_retention, 0.16)
    floor = Keyword.get(opts, :activity_floor, 0.005)

    activity
    |> Enum.map(fn {id, value} -> {id, value * retention} end)
    |> Enum.reject(fn {_id, value} -> value < floor end)
    |> Map.new()
  end

  defp active_ids(activity, opts) do
    threshold = Keyword.get(opts, :active_threshold, 0.04)

    activity
    |> Enum.filter(fn {_id, value} -> value >= threshold end)
    |> Enum.map(&elem(&1, 0))
    |> MapSet.new()
  end

  defp normalize(vector) do
    magnitude = :math.sqrt(Enum.sum(Enum.map(vector, &(&1 * &1))))
    if magnitude == 0.0, do: vector, else: Enum.map(vector, &(&1 / magnitude))
  end

  defp zero_vector?(vector), do: Enum.all?(vector, &(abs(&1) < 1.0e-12))
  defp dot(left, right), do: Enum.zip_with(left, right, &(&1 * &2)) |> Enum.sum()
  defp add(left, right), do: Enum.zip_with(left, right, &(&1 + &2))
  defp subtract(left, right), do: Enum.zip_with(left, right, &(&1 - &2))
  defp scale(vector, amount), do: Enum.map(vector, &(&1 * amount))
  defp interpolate(current, proposal, rate), do: Enum.zip_with(current, proposal, &(&1 + (&2 - &1) * rate))

  defp distance(left, right) do
    left
    |> Enum.zip(right)
    |> Enum.reduce(0.0, fn {a, b}, total -> total + :math.pow(a - b, 2) end)
    |> :math.sqrt()
  end
end
