defmodule Exegete.Command do
  @doc "Handle a command execution with the provided command + args list, return the (maybe modified) state"
  @callback handle(list(), Exegete.Client.State.t()) :: Exegete.Client.State.t()

  @doc "Return information about the command used for the COMMAND group of commands."
  @callback command_info() :: Exegete.Command.info()

  @type info() :: %{
          name: String.t(),
          arity: integer(),
          flags: list(),
          first_key: pos_integer(),
          last_key: integer(),
          step: pos_integer(),
          summary: String.t()
        }

  require Logger
  alias Exegete.Protocol

  @top_levels %{
    "HELLO" => Exegete.Command.Hello,
    "COMMAND" => Exegete.Command.Command
  }

  def commands do
    @top_levels
  end

  def handle([top | _rest] = command, state) do
    case @top_levels[top] do
      nil ->
        :gen_tcp.send(
          state.socket,
          Protocol.serialize(
            %Protocol.Error{code: :not_implemented, message: "This command is not implemented."},
            state.proto_version
          )
        )

        Logger.warning("Unimplemented command: #{top}")

        Logger.debug("Full invocation: #{command |> Enum.join(" ")}")

        state

      module ->
        module.handle(command, state)
    end
  end
end
