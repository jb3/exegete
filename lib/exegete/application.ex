defmodule Exegete.Application do
  @moduledoc """
  Top-level application supervisor for the Exegete application.

  Within this module, the core components of Exegete (sockets, etc.) are spawned
  and supervised. View the module source to see the full application tree,
  spawned applications here may themselves be supervisors and as such have their
  own static or dynamic children lists.
  """

  use Application
  import Supervisor

  @impl true
  def start(_type, _args) do
    children = [
      child_spec({Exegete.Socket, :inet}, id: :v4_socket),
      child_spec({Exegete.Socket, :inet6}, id: :v6_socket),
      {DynamicSupervisor, name: Exegete.ClientSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: Exegete.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
