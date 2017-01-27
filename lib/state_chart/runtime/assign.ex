defmodule StateChart.Runtime.Assign do
  use StateChart.Definition do
    field(:string, :id, 1)
    field(:ref, :ref, 2)
    field(:any, :expression, 3)
  end
end
