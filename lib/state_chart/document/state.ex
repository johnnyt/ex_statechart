defmodule StateChart.Document.State do
  use StateChart.Definition do
    field(:string, :id, 1)
    field(:ref, :self, 1)
    enum Type, :type, 2, [
      composite: 0,
      initial: 1,
      history: 2,
      final: 3,
      basic: 4,
      parallel: 5
    ]
    field(:ref, :initial, 3)
    repeated(StateChart.Runtime.Invoke, :invocations, 4)
    repeated(:any, :on_entry, 4)
    repeated(:any, :on_exit, 5)
    repeated(Model.Transition, :transitions, 6)
    repeated(:ref, :children, 8)
    repeated(:ref, :ancestors, 9)
    repeated(:ref, :descendants, 10)
    field(:ref, :parent, 11)
    field(:uint32, :priority, 13)
    enum History, :history, 14, [
      shallow: 0,
      deep: 1
    ]

    computed(:ancestors_set, fn(%{ancestors: d}) ->
      MapSet.new(d)
    end)
    computed(:descendants_set, fn(%{descendants: d}) ->
      MapSet.new(d)
    end)
    computed(:depth, fn(%{ancestors_set: s}) ->
      MapSet.size(s)
    end)
    computed(:id, fn
      (%{id: "", ref: ref}) ->
        {:__computed__, ref}
      (%{id: id}) ->
        id
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
end
