defmodule Exegete.Client do
  use GenServer

  alias Exegete.{Client.State, Protocol}
  require Logger

  def start_link(client) do
    GenServer.start_link(__MODULE__, client)
  end

  def init(client) do
    {:ok, {addr, port}} = :inet.peername(client)

    Logger.metadata(client_addr: :inet.ntoa(addr) |> List.to_string(), client_port: port, db: 0)

    Logger.info("Connection opened")

    {:ok,
     %State{
       socket: client,
       client_addr: addr,
       client_port: port,
       write_buffer: [],
       proto_version: 2,
       db: 0
     }}
  end

  def handle_info(
        {:tcp, _port, message},
        %State{write_buffer: write_buffer} = state
      ) do
    # Append whatever new data we have to the existing write buffer
    write_buffer =
      write_buffer ++ (message |> String.trim_trailing("\r\n") |> String.split("\r\n"))

    # Attempt to deserialize
    {deserialized, _remaining} = Protocol.deserialize(write_buffer)

    case deserialized do
      :error ->
        Logger.warning("Client sent invalid payload")

        msg =
          Protocol.serialize(
            %Exegete.Protocol.Error{
              code: :syntax_parse,
              message: "Syntax error in RESP payload."
            },
            state.proto_version
          )

        :gen_tcp.send(state.socket, msg)

        {:noreply, %{state | write_buffer: []}}

      :more ->
        Logger.debug("Client sent incomplete payload")
        {:noreply, %{state | write_buffer: write_buffer}}

      [_head | _rest] ->
        {:noreply, Exegete.Command.handle(deserialized, state)}

      _ ->
        msg =
          Protocol.serialize(
            %Exegete.Protocol.Error{
              code: :syntax_unexp,
              message: "Invalid payload, expected command."
            },
            state.proto_version
          )

        :gen_tcp.send(state.socket, msg)

        {:noreply, state}
    end
  end

  def handle_info({:tcp_closed, _port}, state) do
    Logger.info("Connection closed")
    {:stop, :normal, state}
  end
end
