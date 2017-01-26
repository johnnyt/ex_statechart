defmodule StateChart.Model.Query do
  alias StateChart.Model
  alias Model.{State}

  def ancestors(model, s, %{id: root}) do
    ancestors(model, s, root)
  end
  def ancestors(_model, %State{ancestors: a}, root) do
    Stream.take_while(a, &(&1 != root))
  end
  def ancestors(model, id, root) do
    state = get(model, id)
    ancestors(model, state, root)
  end

  def orthoganal?(model, %State{} = s1, %State{} = s2) do
    ancestrally_related?(model, s1, s2) && (
      case lca(model, s1, s2) do
        %{type: t} -> t == :parallel
        _ -> false
      end
    )
  end
  def orthoganal?(model, s1, s2) do
    s1 = get(model, s1)
    s2 = get(model, s2)
    orthoganal?(model, s1, s2)
  end

  def ancestrally_related?(_model, %{id: id}, %{id: id}) do
    true
  end
  def ancestrally_related?(
    _model,
    %{id: s1, ancestors_set: s1_a},
    %{id: s2, ancestors_set: s2_a}
  ) do
    MapSet.member?(s2_a, s1) || MapSet.member?(s1_a, s2)
  end
  def ancestrally_related?(model, a, b) do
    a = get(model, a)
    b = get(model, b)
    ancestrally_related?(model, a, b)
  end

  def lca(%{states: s}, %{id: id, parent: parent}, %{id: id}) do
    Map.get(s, parent)
  end
  def lca(%StateChart.Model{states: s}, %{ancestors: a}, %{id: id}) do
    Enum.find_value(a, fn(anc) ->
      {:ok, %{descendants_set: d} = lca} = Map.fetch(s, anc)
      MapSet.member?(d, id) && lca
    end)
  end
  def lca(model, a, b) do
    a = get(model, a)
    b = get(model, b)
    lca(model, a, b)
  end

  defp get(%{states: s}, %State{} = s) do
    s
  end
  defp get(%{states: s}, id) do
    {:ok, state} = Map.fetch(s, id)
    state
  end
end
