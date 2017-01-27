defmodule StateChart.Document.State do
  use StateChart.Definition do
    field(:string, :id, 1)
    field(:ref, :ref, 2)
    enum Type, :type, 3, [
      basic: 0,
      composite: 1,
      parallel: 2,
      history: 3,
      initial: 4,
      final: 5
    ]
    repeated(:ref, :initials, 4, [:initial])
    repeated(StateChart.Runtime.Invoke, :invocations, 5)
    repeated(:any, :on_entry, 6)
    repeated(:any, :on_exit, 7)
    repeated(Model.Transition, :transitions, 8)
    repeated(:ref, :children, 9)
    repeated(:ref, :ancestors, 10)
    repeated(:ref, :descendants, 11)
    field(:ref, :parent, 12)
    field(:uint32, :depth, 13)
    field(:uint32, :priority, 14)
    field(:ref, :history, 15)
    enum History, :history_type, 16, [
      shallow: 0,
      deep: 1
    ]

    computed(:id, fn
      (%{id: "", ref: ref}) ->
        ref
      (%{id: id}) ->
        id
    end)
    computed(:ancestors_set, fn(%{ancestors: d}) ->
      MapSet.new(d)
    end)
    computed(:descendants_set, fn(%{descendants: d}) ->
      MapSet.new(d)
    end)
    computed(:depth, fn(%{ancestors_set: s}) ->
      MapSet.size(s)
    end)
  end

  def compare(%{depth: d, priority: p}, %{depth: d, priority: p}), do: true
  def compare(%{depth: d, priority: p1}, %{depth: d, priority: p2}) do
    p1 < p2
  end
  def compare(%{depth: d1}, %{depth: d2}) do
    d1 >= d2
  end

  def on_enter(%{on_entry: on_entry}, context) do
    Enum.reduce(on_entry, context, &StateChart.Context.execute(&2, &1))
  end

  def on_exit(%{on_exit: on_exit}, context) do
    Enum.reduce(on_exit, context, &StateChart.Context.execute(&2, &1))
  end

  alias StateChart.Document.{Analyzer,Transition}
  def finalize(
    %{initials: initials,
      transitions: transitions,
      children: children,
      ancestors: ancestors,
      descendants: descendants,
      parent: parent,
      history: history} = state,
    doc
  ) do
    ancestors = Enum.map(ancestors, &Analyzer.deref(doc, &1))
    descendants = Enum.map(descendants, &Analyzer.deref(doc, &1))
    %{state |
      initials: Enum.map(initials, &Analyzer.deref(doc, &1)),
      transitions: Enum.map(transitions, &Transition.finalize(&1, doc)),
      children: Enum.map(children, &Analyzer.deref(doc, &1)),
      ancestors: ancestors,
      ancestors_set: MapSet.new(ancestors),
      descendants: descendants,
      descendants_set: MapSet.new(descendants),
      parent: Analyzer.deref(doc, parent),
      history: Analyzer.deref(doc, history)
    }
  end
end
