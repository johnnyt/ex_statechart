defmodule StateChart.Queue do
  defstruct [
    size: 0,
    data: :queue.new()
  ]

  def new(items \\ []) do
    Enum.reduce(items, %__MODULE__{}, &enqueue(&2, &1))
  end

  def enqueue(%{data: q, size: s}, item) do
    q = :queue.in(item, q)
    %__MODULE__{data: q, size: s + 1}
  end

  def dequeue(%{data: q, size: 0}) do
    :empty
  end
  def dequeue(%{data: q, size: s}) do
    {{:value, v}, q} = :queue.out(q)
    {v, %__MODULE__{data: q, size: s - 1}}
  end
end
