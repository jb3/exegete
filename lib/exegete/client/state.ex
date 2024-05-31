defmodule Exegete.Client.State do
  @moduledoc """
  Struct representing the state of a client connected to the Exegete server.

  Some of this state is mutated thorughout the course of a connection by a client
  executing commands on the server.
  """

  defstruct [
    :socket,
    :write_buffer,
    :client_addr,
    :client_port,
    :proto_version,
    :db,
    :client_name
  ]

  @type t() :: %__MODULE__{
          socket: port(),
          write_buffer: list(),
          client_addr: :inet.ip_address(),
          client_port: :inet.port_number(),
          proto_version: 2 | 3,
          db: integer(),
          client_name: String.t()
        }
end
