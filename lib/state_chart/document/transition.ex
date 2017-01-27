defmodule StateChart.Document.Transition do
  use StateChart.Definition do
    field(:ref, :source, 1)
    repeated(:ref, :targets, 2, [:target])
    repeated(:string, :events, 3, [:event])
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

  def match?(%{events: []}, _name) do
    true
  end
  def match?(%{events: events}, name) do
    Enum.member?(events, name)
  end

  def compare(%{depth: d, priority: p}, %{depth: d, priority: p}), do: true
  def compare(%{depth: d, priority: p1}, %{depth: d, priority: p2}) do
    p1 < p2
  end
  def compare(%{depth: d1}, %{depth: d2}) do
    d1 >= d2
  end

  def on_condition(%{condition: nil}, _) do
    true
  end
  def on_condition(%{condition: condition}, context) do
    StateChart.Context.query(context, condition)
  end

  def on_transition(%{on_transition: on_transition}, context) do
    Enum.reduce(on_transition, context, &StateChart.Context.execute(&2, &1))
  end

  alias StateChart.Document.Analyzer
  def finalize(
    %{source: source, targets: targets, scope: scope} = transition,
    doc
  ) do
    %{transition |
      source: Analyzer.deref(doc, source),
      targets: Enum.map(targets, &Analyzer.deref(doc, &1)),
      scope: Analyzer.deref(doc, scope)
    }
  end
end
