defmodule Procession.Simulation.DevelopmentalMotorBody do
  @moduledoc """
  A low-level motor substrate where coordinated movement is learned rather than exposed
  as a pre-existing action vocabulary.

  Callers activate opaque motor channels in small patterns. The body converts the
  combined activation into noisy physical force. Repeated patterns that produce a
  consistent sensed consequence become more coordinated and therefore more reliable.
  """

  @channels [:m1, :m2, :m3, :m4, :m5, :m6, :m7, :m8]
  @patterns for a <- @channels, b <- @channels, a < b, do: {a, b}

  defstruct coordination: %{},
            effect_memory: %{},
            attempts: 0,
            successful_displacements: 0,
            stable_patterns: MapSet.new()

  @type direction :: :north | :south | :east | :west | :none
  @type pattern :: {atom(), atom()}
  @type outcome :: %{
          pattern: pattern(),
          direction: direction(),
          displaced?: boolean(),
          blocked?: boolean(),
          intensity: float(),
          coordination: float(),
          consequence: atom()
        }

  @spec new(keyword()) :: t() when t: %__MODULE__{}
  def new(opts \\ []) do
    initial = Keyword.get(opts, :initial_coordination, 0.015)

    coordination =
      Map.new(@patterns, fn pattern ->
        jitter = :erlang.phash2({:initial_coordination, pattern}, 100) / 100_000
        {pattern, initial + jitter}
      end)

    %__MODULE__{coordination: coordination}
  end

  @spec channels() :: [atom()]
  def channels, do: @channels

  @spec patterns() :: [pattern()]
  def patterns, do: @patterns

  @doc "Choose an opaque two-channel motor activation pattern."
  @spec choose_pattern(%__MODULE__{}, integer(), integer(), keyword()) :: pattern()
  def choose_pattern(body, tick, seed, opts \\ []) do
    exploration = Keyword.get(opts, :exploration, 0.92)

    scored =
      Enum.map(@patterns, fn pattern ->
        learned = Map.get(body.coordination, pattern, 0.0)
        noise = :erlang.phash2({seed, tick, pattern}, 10_000) / 10_000
        score = learned * (1.0 - exploration) + noise * exploration
        {pattern, score}
      end)

    scored
    |> Enum.max_by(fn {pattern, score} -> {score, pattern} end)
    |> elem(0)
  end

  @doc """
  Activate a low-level motor pattern.

  `position` and `bounds` are physical facts owned by the body/world. The returned
  direction is an observed consequence, not an action selected by the learner.
  """
  @spec attempt(%__MODULE__{}, pattern(), {integer(), integer()}, integer(), keyword()) ::
          {%__MODULE__{}, outcome()}
  def attempt(body, pattern, position, tick, opts \\ []) do
    seed = Keyword.get(opts, :seed, 1)
    bounds = Keyword.get(opts, :bounds, {3, 3})
    coordination = Map.fetch!(body.coordination, normalize(pattern))
    force = force_for(pattern)
    intensity = force_intensity(force)

    success_threshold =
      0.985 - min(0.82, coordination * 0.90) + max(0.0, 0.18 - intensity) * 0.25

    roll = :erlang.phash2({:motor_attempt, seed, tick, pattern, body.attempts}, 10_000) / 10_000
    direction = dominant_direction(force, roll, coordination)
    displaced? = direction != :none and roll >= success_threshold
    blocked? = displaced? and blocked?(position, direction, bounds)

    consequence =
      cond do
        not displaced? -> :uncoordinated_activation
        blocked? -> :resisted_displacement
        true -> :displacement
      end

    outcome = %{
      pattern: normalize(pattern),
      direction: if(displaced?, do: direction, else: :none),
      displaced?: displaced? and not blocked?,
      blocked?: blocked?,
      intensity: intensity,
      coordination: coordination,
      consequence: consequence
    }

    {learn_from_consequence(body, outcome), outcome}
  end

  @doc "Apply the body's observed displacement to a bounded grid."
  def apply_displacement(position, %{displaced?: false}), do: position
  def apply_displacement({x, y}, %{direction: :north}), do: {x, max(0, y - 1)}
  def apply_displacement({x, y}, %{direction: :south}), do: {x, y + 1}
  def apply_displacement({x, y}, %{direction: :east}), do: {x + 1, y}
  def apply_displacement({x, y}, %{direction: :west}), do: {max(0, x - 1), y}

  @doc "Record a caregiver-supported consequence while retaining learner pattern ownership."
  @spec supported_attempt(%__MODULE__{}, pattern(), direction(), float()) :: %__MODULE__{}
  def supported_attempt(body, pattern, observed_direction, support)
      when observed_direction in [:north, :south, :east, :west] and support >= 0.0 do
    pattern = normalize(pattern)
    current = Map.get(body.coordination, pattern, 0.0)
    gain = 0.008 + min(1.0, support) * 0.018
    updated = min(1.0, current + gain * (1.0 - current))

    %{body |
      coordination: Map.put(body.coordination, pattern, updated),
      effect_memory: update_effect(body.effect_memory, pattern, observed_direction, gain),
      stable_patterns: stable_patterns(body.stable_patterns, pattern, updated)}
  end

  @spec stable_pattern_count(%__MODULE__{}) :: non_neg_integer()
  def stable_pattern_count(body), do: MapSet.size(body.stable_patterns)

  @spec strongest_patterns(%__MODULE__{}, non_neg_integer()) :: [{pattern(), float()}]
  def strongest_patterns(body, limit \\ 5) do
    body.coordination
    |> Enum.sort_by(fn {_pattern, strength} -> -strength end)
    |> Enum.take(limit)
  end

  defp learn_from_consequence(body, outcome) do
    current = Map.get(body.coordination, outcome.pattern, 0.0)

    delta =
      case outcome.consequence do
        :displacement -> 0.010 * (1.0 - current)
        :resisted_displacement -> 0.002 * (1.0 - current)
        :uncoordinated_activation -> 0.00015 * (1.0 - current)
      end

    updated = min(1.0, current + delta)
    effects =
      if outcome.displaced? do
        update_effect(body.effect_memory, outcome.pattern, outcome.direction, delta)
      else
        body.effect_memory
      end

    %{body |
      coordination: Map.put(body.coordination, outcome.pattern, updated),
      effect_memory: effects,
      attempts: body.attempts + 1,
      successful_displacements: body.successful_displacements + if(outcome.displaced?, do: 1, else: 0),
      stable_patterns: stable_patterns(body.stable_patterns, outcome.pattern, updated)}
  end

  defp update_effect(memory, pattern, direction, gain) do
    Map.update(memory, pattern, %{direction => gain}, fn directions ->
      Map.update(directions, direction, gain, &(&1 + gain))
    end)
  end

  defp stable_patterns(set, pattern, strength) when strength >= 0.30,
    do: MapSet.put(set, pattern)
  defp stable_patterns(set, _pattern, _strength), do: set

  defp normalize({a, b}) when a < b, do: {a, b}
  defp normalize({a, b}), do: {b, a}

  # These are body mechanics, not learner-visible action meanings. Individual channels
  # contribute conflicting forces; only combined patterns can create a dominant result.
  defp channel_force(:m1), do: {-0.42, -0.18}
  defp channel_force(:m2), do: {0.38, -0.22}
  defp channel_force(:m3), do: {-0.20, 0.44}
  defp channel_force(:m4), do: {0.24, 0.40}
  defp channel_force(:m5), do: {-0.34, 0.16}
  defp channel_force(:m6), do: {0.36, 0.12}
  defp channel_force(:m7), do: {-0.08, -0.38}
  defp channel_force(:m8), do: {0.10, 0.36}

  defp force_for({a, b}) do
    {ax, ay} = channel_force(a)
    {bx, by} = channel_force(b)
    {ax + bx, ay + by}
  end

  defp force_intensity({x, y}), do: min(1.0, :math.sqrt(x * x + y * y))

  defp dominant_direction({x, y}, roll, coordination) do
    wobble = (roll - 0.5) * max(0.0, 0.42 - coordination)
    x = x + wobble
    y = y - wobble

    cond do
      abs(x) < 0.16 and abs(y) < 0.16 -> :none
      abs(x) >= abs(y) and x > 0.0 -> :east
      abs(x) >= abs(y) -> :west
      y > 0.0 -> :south
      true -> :north
    end
  end

  defp blocked?({0, _y}, :west, _bounds), do: true
  defp blocked?({_x, 0}, :north, _bounds), do: true
  defp blocked?({max_x, _y}, :east, {max_x, _max_y}), do: true
  defp blocked?({_x, max_y}, :south, {_max_x, max_y}), do: true
  defp blocked?(_position, _direction, _bounds), do: false
end
