defmodule StateChart.Document.Query do
  alias StateChart.Document
  alias Document.{State}

  def ancestors(document, s, %{id: root}) do
    ancestors(document, s, root)
  end
  def ancestors(_document, %State{ancestors: a}, root) do
    Stream.take_while(a, &(&1 != root))
  end
  def ancestors(document, id, root) do
    state = get(document, id)
    ancestors(document, state, root)
  end

  def orthoganal?(document, %State{} = s1, %State{} = s2) do
    ancestrally_related?(document, s1, s2) && (
      case lca(document, s1, s2) do
        %{type: t} -> t == :parallel
        _ -> false
      end
    )
  end
  def orthoganal?(document, s1, s2) do
    s1 = get(document, s1)
    s2 = get(document, s2)
    orthoganal?(document, s1, s2)
  end

  def ancestrally_related?(_document, %{id: id}, %{id: id}) do
    true
  end
  def ancestrally_related?(
    _document,
    %{id: s1, ancestors_set: s1_a},
    %{id: s2, ancestors_set: s2_a}
  ) do
    MapSet.member?(s2_a, s1) || MapSet.member?(s1_a, s2)
  end
  def ancestrally_related?(document, a, b) do
    a = get(document, a)
    b = get(document, b)
    ancestrally_related?(document, a, b)
  end

  def lca(%{states: s}, %{id: id, parent: parent}, %{id: id}) do
    Map.get(s, parent)
  end
  def lca(%StateChart.Document{states: s}, %{ancestors: a}, %{id: id}) do
    Enum.find_value(a, fn(anc) ->
      {:ok, %{descendants_set: d} = lca} = Map.fetch(s, anc)
      MapSet.member?(d, id) && lca
    end)
  end
  def lca(document, a, b) do
    a = get(document, a)
    b = get(document, b)
    lca(document, a, b)
  end

  defp get(%{states: s}, %State{} = s) do
    s
  end
  defp get(%{states: s}, id) do
    {:ok, state} = Map.fetch(s, id)
    state
  end
end
