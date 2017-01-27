defmodule StateChart.Runtime.Foreach do
  use StateChart.Definition do
    field(:any, :array, 1)
    field(:var, :item, 2)
    field(:var, :index, 2)
    repeated(:any, :children, 4)
  end
end
