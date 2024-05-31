defmodule Exegete.Protocol.RESP3 do
  @moduledoc """
  Implementation of the newer RESP3 protocol for Redis serialization.

  Note that this only really adds new types and otherwise remains backwards
  compatible with RESP2, implementation-wise the module will fall back to RESP2
  for any data type it does not otherwise override.
  """
  alias Exegete.{Protocol, Protocol.RESP2}

  def serialize({:push, objects}) do
    Protocol.types_to_bytes()[:push] <>
      Integer.to_string(length(objects)) <> "\r\n" <> Enum.join(Enum.map(objects, &serialize/1))
  end

  def serialize({:error, data} = error) do
    if String.contains?(data, "\n") or String.contains?(data, "\r") do
      Protocol.types_to_bytes()[:bulk_error] <> RESP2.serialize_string(data)
    else
      RESP2.serialize(error)
    end
  end

  def serialize(%MapSet{} = data) do
    serialized_elements =
      Enum.map(data, fn x ->
        serialize(x)
      end)

    Protocol.types_to_bytes()[:set] <>
      Integer.to_string(MapSet.size(data)) <> "\r\n" <> Enum.join(serialized_elements)
  end

  def serialize(%{} = data) do
    size = length(Map.keys(data))

    rest =
      Enum.flat_map(data, fn {k, v} ->
        [
          serialize(k),
          serialize(v)
        ]
      end)

    Protocol.types_to_bytes()[:map] <> Integer.to_string(size) <> "\r\n" <> Enum.join(rest)
  end

  def serialize(data) when is_float(data) do
    Protocol.types_to_bytes()[:double] <> Float.to_string(data) <> "\r\n"
  end

  def serialize({:null, _}) do
    Protocol.types_to_bytes()[:null] <> "\r\n"
  end

  def serialize(data) when is_integer(data) do
    if Integer.digits(data, 2) |> length > 64 do
      Protocol.types_to_bytes()[:big_number] <> Integer.to_string(data) <> "\r\n"
    else
      RESP2.serialize(data)
    end
  end

  def serialize(other) do
    RESP2.serialize(other)
  end
end
