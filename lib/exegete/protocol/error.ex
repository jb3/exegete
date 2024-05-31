defmodule Exegete.Protocol.Error do
  @moduledoc """
  Struct representing an error anywhere within the connection. This can be used
  to symbolise a syntax error with a command or an operational error with the
  execution of a command.

  It stores an atom code as well as a human readable message.
  """
  defstruct [
    :code,
    :message
  ]

  @type t() :: %__MODULE__{
          code: atom(),
          message: String.t()
        }

  @doc """
  Format an error into a nicely formatted human readable string ready to be
  sent in a RESP-serialized error payload.

  ```elixir
  iex> error = %Exegete.Protocol.Error{code: :syntax, message: "Invalid syntax!"}
  %Exegete.Protocol.Error{code: :syntax, message: "Invalid syntax!"}
  iex> Exegete.Protocol.Error.format(error)
  "SYNTAX Invalid syntax!"
  ```
  """
  def format(%__MODULE__{} = error) do
    (Atom.to_string(error.code) |> String.upcase()) <> " " <> error.message
  end
end
