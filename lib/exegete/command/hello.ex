defmodule Exegete.Command.Hello do
  @behaviour Exegete.Command

  alias Exegete.Protocol

  require Logger

  @impl true
  def command_info do
    %{
      name: "hello",
      arity: -1,
      flags: [],
      first_key: 0,
      last_key: 0,
      step: 0,
      summary: "Perform a handshake with the Redis server."
    }
  end

  def prepare_server_info(state) do
    %{
      "server" => "exegete",
      "version" => List.to_string(Application.spec(:exegete)[:vsn]),
      "proto" => 3,
      "name" => state.client_name,
      "db" => state.db,
      "mode" => "standalone",
      "modules" => {:null, :array}
    }
  end

  @impl true
  def handle(["HELLO"], state) do
    message = Protocol.serialize(prepare_server_info(state), state.proto_version)

    :gen_tcp.send(state.socket, message)

    state
  end

  @impl true
  def handle(command, state) do
    [_command | rest] = command

    # TODO: Handle SET NAME and AUTH attached to HELLO commands
    [requested_proto | _other] = rest

    case Integer.parse(requested_proto) do
      {proto, _} when proto in [2, 3] ->
        new_state = %{state | proto_version: proto}

        message = Protocol.serialize(prepare_server_info(state), proto)

        Logger.info("Switching to RESP#{proto} protocol")

        :gen_tcp.send(state.socket, message)

        new_state

      _ ->
        :gen_tcp.send(
          state.socket,
          Protocol.serialize(
            %Protocol.Error{
              code: :bad_proto,
              message: "Only protocols RESP2 and RESP3 are supported"
            },
            state.proto_version
          )
        )

        state
    end
  end
end
