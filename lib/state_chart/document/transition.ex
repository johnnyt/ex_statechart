defmodule StateChart.Document.Transition do
  use StateChart.Definition do
    field(:ref, :source, 1)
    repeated(:ref, :target, 2)
    repeated(:string, :event, 3)
    field(:any, :condition, 4, [:cond])
    enum Type, :type, 5, [
      external: 0,
      internal: 1
    ]
    repeated(:any, :on_transition, 6)
    field(:uint32, :depth, 8)
    field(:uint32, :priority, 9)
    field(:ref, :scope, 10)
  end

  def match?(%{event: []}, name) do
    true
  end
  def match?(%{event: events}, name) do
    Enum.member?(events, name)
  end

  def compare(%{depth: d, priority: p}, %{depth: d, priority: p}), do: true
  def compare(%{depth: d, priority: p1}, %{depth: d, priority: p2}) do
    p1 < p2
  end
  def compare(%{depth: d1}, %{depth: d2}) do
    d1 >= d2
  end

  def on_condition(%{conditions: conditions}, context) do
    Enum.all?(conditions, &StateChart.Context.query(context, &1))
  end

  def on_transition(%{on_transition: on_transition}, context) do
    Enum.reduce(on_transition, context, &StateChart.Context.execute(&2, &1))
  end
end
