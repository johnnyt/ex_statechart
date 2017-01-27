defmodule StateChart.Configuration do
  alias StateChart.{Interpreter,Document.State}

  def active_states(%Interpreter{configuration: conf}) do
    active_states(conf)
  end
  def active_states(conf) do
    conf
    |> Stream.map(fn(%State{id: id}) -> id end)
    |> Enum.into(MapSet.new())
  end

  def all_active_states(%Interpreter{configuration: conf}) do
    all_active_states(conf)
  end
  def all_active_states(conf) do
    conf
    |> Stream.flat_map(fn(%{id: id, ancestors: a}) ->
      [id | a]
    end)
    |> Enum.into(MapSet.new())
  end

  def active?(configuration, name) do
    configuration
    |> all_active_states()
    |> MapSet.member?(name)
  end
end
