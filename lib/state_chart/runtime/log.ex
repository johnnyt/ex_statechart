defmodule StateChart.Runtime.Log do
  use StateChart.Definition do
    field(:string, :label, 1)
    field(:any, :expression, 2, [:expr])
  end
end
