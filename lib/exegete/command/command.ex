defmodule Exegete.Command.Command do
  @behaviour Exegete.Command
  @moduledoc "Command for fetching metadata on commands compatible with the Exegete server."

  alias Exegete.Protocol

  require Logger

  @impl true
  def command_info do
    %{
      name: "command",
      arity: -1,
      flags: [],
      first_key: 0,
      last_key: 0,
      step: 0,
      summary: "Return information about all commands."
    }
  end

  @impl true
  def handle(["COMMAND"], state) do
    Logger.debug("Listing all commands")

    all_commands = Exegete.Command.commands()

    command_info =
      Enum.map(all_commands, fn {_command, mod} ->
        info = mod.command_info()

        [
          info.name,
          info.arity,
          info.flags,
          info.first_key,
          info.last_key,
          info.step
        ]
      end)

    message = Protocol.serialize(command_info, state.proto_version)

    :gen_tcp.send(state.socket, message)

    state
  end

  @impl true
  def handle(["COMMAND", "DOCS"], state) do
    Logger.debug("Listing all command documentation")

    all_commands = Exegete.Command.commands()

    command_docs =
      Map.new(
        Enum.map(all_commands, fn {command, mod} ->
          info = mod.command_info()

          {command,
           %{
             summary: info.summary
           }}
        end)
      )

    message = Protocol.serialize(command_docs, state.proto_version)

    :gen_tcp.send(state.socket, message)

    state
  end

  @impl true
  def handle(["COMMAND", "DOCS", search_command | rest], state) do
    all_commands = Exegete.Command.commands()

    command_docs =
      Enum.map(all_commands, fn {_command, mod} ->
        info = mod.command_info()

        {info.name,
         %{
           summary: info.summary
         }}
      end)
      |> Enum.filter(fn {command, _info} ->
        String.downcase(search_command) == String.downcase(command) or
          Enum.member?(rest |> Enum.map(&String.downcase/1), String.downcase(command))
      end)
      |> Map.new()

    message = Protocol.serialize(command_docs, state.proto_version)

    :gen_tcp.send(state.socket, message)

    state
  end
end
