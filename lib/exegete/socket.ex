defmodule Exegete.Socket do
  @moduledoc """
  Entry socket for connections to the Exegete application.

  This socket handles the first connection from client applications and the
  spawning of necessary sub-handlers to process client commands.

  There are technically two sockets within this to handle both IPv4 and IPv6
  clients.
  """

  use GenServer

  require Logger

  def start_link(mode) do
    GenServer.start_link(__MODULE__, mode)
  end

  defp get_listen_ip(mode) do
    addr =
      case mode do
        :inet -> Application.get_env(:exegete, :ipv4_addr, "127.0.0.1")
        :inet6 -> Application.get_env(:exegete, :ipv6_addr, "::1")
      end

    try do
      as_charlist = String.to_charlist(addr)
      {:ok, parsed_address} = :inet.parse_strict_address(as_charlist, mode)

      parsed_address
    rescue
      [FunctionClauseError, MatchError] ->
        Logger.critical("Invalid IP passed for #{mode} address, could not parse: #{addr}")
        Logger.flush()
        System.halt(1)
    end
  end

  @impl true
  def init(mode) do
    Logger.metadata(family: mode)

    port = Application.get_env(:exegete, :listen_port, 6379)

    addr = get_listen_ip(mode)

    {:ok, socket} =
      case mode do
        :inet ->
          # Start the listening socket for IPv4
          :gen_tcp.listen(port, [
            :binary,
            ip: addr,
            active: false,
            reuseaddr: true
          ])

        :inet6 ->
          # Start the listening socket for IPv6
          :gen_tcp.listen(port, [
            :binary,
            :inet6,
            ip: addr,
            active: false,
            reuseaddr: true
          ])
      end

    send(self(), :loop)

    {:ok, socket}
  end

  @impl true
  @doc """
  Acceptor loop for the primary socket.

  Whilst two sockets are spawned for the IPv4 and IPv6 accept loops, the logic
  is largely the same and this callback is agnostic.

  This loop does a number of things:
  - Accept the incoming connection
  - Spawn a new client GenServer under the client supervisor
  - Set the controlling process of the connected socket to this process
  - Change the socket receive type to active (send messages instead of polling)
  - Repeat the acceptor loop
  """
  def handle_info(:loop, socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    Logger.info("Socket received new connection, handing over to ClientSupervisor.")

    setup_client(client)

    send(self(), :loop)

    {:noreply, socket}
  end

  defp setup_client(client) do
    {:ok, spawned_handler} =
      DynamicSupervisor.start_child(Exegete.ClientSupervisor, {Exegete.Client, client})

    :inet_tcp.controlling_process(client, spawned_handler)

    :inet.setopts(client, active: true)
  end
end
