defmodule Procession.AI.NPCInteraction.Validator do
  @moduledoc """
  Deterministic validation for NPC interaction responses.

  This module inspects generated NPC dialogue and returns validation results as data.
  It does not call AI, mutate entity state, mutate memory, create behavior metadata,
  or change world state.
  """

  @type validation_error :: %{
          code: atom(),
          message: String.t()
        }

  @type validation_result :: {:ok, String.t()} | {:error, [validation_error()]}

  @doc """
  Validates a generated NPC interaction response against grounded dialogue context.
  """
  @spec validate_response(map(), term()) :: validation_result()
  def validate_response(context, response)

  def validate_response(context, response) when is_map(context) and is_binary(response) do
    errors =
      []
      |> validate_not_blank(response)
      |> validate_identity_claim(context, response)

    case errors do
      [] -> {:ok, response}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  def validate_response(_context, _response) do
    {:error,
     [
       %{
         code: :invalid_response,
         message: "NPC interaction response must be a string."
       }
     ]}
  end

  defp validate_not_blank(errors, response) do
    if String.trim(response) == "" do
      [
        %{
          code: :blank_response,
          message: "NPC interaction response cannot be blank."
        }
        | errors
      ]
    else
      errors
    end
  end

  defp validate_identity_claim(errors, context, response) do
    target = Map.get(context, :target, %{})
    target_name = Map.get(target, :name)

    context
    |> other_active_npc_names(target_name)
    |> Enum.reduce(errors, fn other_name, acc ->
      if claims_identity?(response, other_name) do
        [
          %{
            code: :target_identity_violation,
            message: "NPC response appears to claim identity as #{other_name}."
          }
          | acc
        ]
      else
        acc
      end
    end)
  end

  defp other_active_npc_names(context, target_name) do
    context
    |> Map.get(:active_entities, [])
    |> Enum.filter(fn entity ->
      Map.get(entity, :type) == :npc and Map.get(entity, :name) != target_name
    end)
    |> Enum.map(&Map.get(&1, :name))
    |> Enum.filter(&is_binary/1)
  end

  defp claims_identity?(response, other_name) do
    response = String.downcase(response)
    other_name = String.downcase(other_name)

    identity_patterns = [
      "i am #{other_name}",
      "i'm #{other_name}",
      "my name is #{other_name}",
      "this is #{other_name}"
    ]

    Enum.any?(identity_patterns, &String.contains?(response, &1))
  end
end
