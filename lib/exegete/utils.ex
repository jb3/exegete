defmodule Exegete.Utils do
  @moduledoc """
  Various high-level utilities used around the application.
  """

  @doc """
  Format an IPv4 or IPv6 address tuple, optionally also accepting a port.

  This is primarily used for debug logging.
  """
  @spec format_ip(:inet.ip_address(), integer() | nil) :: String.t()
  def format_ip(addr, port \\ nil) do
    # Handle v4 address
    address = :inet.ntoa(addr)

    List.to_string(address) <> maybe_port(port)
  end

  defp maybe_port(nil) do
    ""
  end

  defp maybe_port(port) when is_integer(port) do
    ":#{port}"
  end
end
