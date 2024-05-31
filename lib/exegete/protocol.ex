defmodule Exegete.Protocol do
  @moduledoc """
  Functions for serializing and deserializing data into Redis serialization format.
  """

  alias Exegete.Protocol.{Error, RESP2, RESP3}

  @type_to_byte %{
    simple_string: "+",
    simple_error: "-",
    integer: ":",
    bulk_string: "$",
    array: "*",
    null: "_",
    boolean: "#",
    double: ",",
    big_number: "(",
    bulk_error: "!",
    verbatim_string: "=",
    map: "%",
    set: "~",
    push: ">"
  }

  @byte_to_type Map.new(Enum.map(@type_to_byte, fn {type, byte} -> {byte, type} end))

  def types_to_bytes do
    @type_to_byte
  end

  def byte_to_type do
    @byte_to_type
  end

  def deserialize(buffer) do
    [message | rest] = buffer

    {type_byte, seg_remaining} = String.split_at(message, 1)

    type = @byte_to_type[type_byte]

    if type do
      deserialize_component(type, seg_remaining, rest)
    else
      {:error, buffer}
    end
  end

  def deserialize_component(:verbatim_string, segment_remaining, buffer_remaining) do
    {parsed, buf_remain} =
      deserialize_component(:bulk_string, segment_remaining, buffer_remaining)

    [encoding, string] = String.split(parsed, ":", parts: 2)

    {%{encoding: encoding, data: string}, buf_remain}
  end

  def deserialize_component(type, "-1", buffer_remaining)
      when type in [:bulk_string, :array] do
    case type do
      :bulk_string -> {{:null, :string}, buffer_remaining}
      :array -> {{:null, :array}, buffer_remaining}
    end
  end

  def deserialize_component(:push, segment_remaining, buffer_remaining) do
    array_length = String.to_integer(segment_remaining)

    case parse_array(array_length, buffer_remaining) do
      {:more, []} ->
        {:more, []}

      {:error, []} ->
        {:error, []}

      {parsed, buf_remaining} ->
        {{:push, parsed}, buf_remaining}
    end
  end

  def deserialize_component(:array, segment_remaining, buffer_remaining) do
    array_length = String.to_integer(segment_remaining)

    parse_array(array_length, buffer_remaining)
  end

  def deserialize_component(:bulk_string, segment_remaining, buffer_remaining) do
    string_length = String.to_integer(segment_remaining)

    rest = Enum.join(buffer_remaining, "\r\n")

    {taken_bytes, unrelated} = String.split_at(rest, string_length + 1)

    {String.trim_trailing(taken_bytes, "\r\n"), String.split(unrelated, "\r\n")}
  end

  def deserialize_component(:bulk_error, segment_remaining, buffer_remaining) do
    {parsed, buf_remain} =
      deserialize_component(:bulk_string, segment_remaining, buffer_remaining)

    {{:error, parsed}, buf_remain}
  end

  def deserialize_component(:simple_string, segment_remaining, buffer_remaining) do
    {String.trim_trailing(segment_remaining, "\r\n"), buffer_remaining}
  end

  def deserialize_component(:simple_error, segment_remaining, buffer_remaining) do
    {{:error, segment_remaining}, buffer_remaining}
  end

  def deserialize_component(:null, _segment_remaining, buffer_remaining) do
    {nil, buffer_remaining}
  end

  def deserialize_component(:double, segment_remaining, buffer_remaining) do
    case Float.parse(segment_remaining) do
      {num, _rest} -> {num, buffer_remaining}
      _ -> {:error, buffer_remaining}
    end
  end

  def deserialize_component(type, segment_remaining, buffer_remaining)
      when type in [:integer, :big_number] do
    case Integer.parse(segment_remaining) do
      {num, _rest} -> {num, buffer_remaining}
      _ -> {:error, buffer_remaining}
    end
  end

  def deserialize_component(:boolean, segment_remaining, buffer_remaining) do
    case segment_remaining do
      "t" -> {true, buffer_remaining}
      "f" -> {false, buffer_remaining}
      _ -> {:error, buffer_remaining}
    end
  end

  def deserialize_component(:map, segment_remaining, buffer_remaining) do
    map_size = String.to_integer(segment_remaining)

    case parse_array(map_size * 2, buffer_remaining) do
      {:more, []} ->
        {:more, []}

      {:error, []} ->
        {:error, []}

      {parsed, buffer} ->
        new_map =
          Enum.chunk_every(parsed, 2)
          |> Enum.map(fn [k, v] -> {k, v} end)
          |> Map.new()

        {new_map, buffer}
    end
  end

  def deserialize_component(:set, segment_remaining, buffer_remaining) do
    set_size = String.to_integer(segment_remaining)

    case parse_array(set_size, buffer_remaining) do
      {:more, []} ->
        {:more, []}

      {:error, []} ->
        {:error, []}

      {parsed, buffer} ->
        {MapSet.new(parsed), buffer}
    end
  end

  defp parse_array(to_parse, buffer, parsed \\ [])

  defp parse_array(0, buffer, parsed) do
    {parsed, buffer}
  end

  defp parse_array(_to_parse, [], _parsed) do
    {:more, []}
  end

  defp parse_array(_to_parse, [""], _parsed) do
    {:more, []}
  end

  defp parse_array(to_parse, buffer, parsed) do
    {term, remaining_buffer} = deserialize(buffer)

    case term do
      :more ->
        {:more, []}

      :error ->
        {:error, []}

      _ ->
        parse_array(to_parse - 1, remaining_buffer, parsed ++ [term])
    end
  end

  def serialize(%Error{} = error, proto) do
    serialize({:error, Error.format(error)}, proto)
  end

  def serialize(message, 2) do
    RESP2.serialize(message)
  end

  def serialize(message, 3) do
    RESP3.serialize(message)
  end
end
