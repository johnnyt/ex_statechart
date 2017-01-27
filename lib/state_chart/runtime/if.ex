defmodule StateChart.Runtime.If do
  use StateChart.Definition do
    field(:any, :condition, 1, [:cond])
    repeated(:any, :children, 2)
    repeated(:any, :else, 3)
  end
end
