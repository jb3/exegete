defmodule Exegete.Protocol.RESP2 do
  alias Exegete.Protocol

  def serialize(%{} = data) do
    data =
      Enum.flat_map(data, fn {k, v} ->
        [k, v]
      end)

    serialize(data)
  end

  def serialize({:error, data}) do
    Protocol.types_to_bytes()[:simple_error] <> data <> "\r\n"
  end

  def serialize(data) when is_bitstring(data) do
    Protocol.types_to_bytes()[:bulk_string] <> serialize_string(data)
  end

  def serialize({:simple, data}) when is_bitstring(data) do
    Protocol.types_to_bytes()[:simple_string] <> data <> "\r\n"
  end

  def serialize(data) when is_integer(data) do
    Protocol.types_to_bytes()[:integer] <> Integer.to_string(data) <> "\r\n"
  end

  def serialize(data) when is_list(data) do
    Protocol.types_to_bytes()[:array] <>
      Integer.to_string(length(data)) <> "\r\n" <> Enum.join(Enum.map(data, &serialize/1))
  end

  def serialize(nil) do
    serialize({:null, :string})
  end

  def serialize({:null, :string}) do
    Protocol.types_to_bytes()[:bulk_string] <> "-1\r\n"
  end

  def serialize({:null, :array}) do
    Protocol.types_to_bytes()[:array] <> "-1\r\n"
  end

  def serialize(data) when is_atom(data) do
    serialize(Atom.to_string(data))
  end

  def serialize_string(string) do
    Integer.to_string(String.length(string)) <> "\r\n" <> string <> "\r\n"
  end
end
