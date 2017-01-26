defmodule StateChart.OrderedSet do
  # defstruct [
  #   data: []
  # ]

  def new(items \\ []) do
    Enum.to_list(items)
  end

  # TODO
end
