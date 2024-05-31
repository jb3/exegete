defmodule Exegete.Protocol.Error do
  defstruct [
    :code,
    :message
  ]

  def format(%__MODULE__{} = error) do
    (Atom.to_string(error.code) |> String.upcase()) <> " " <> error.message
  end
end
