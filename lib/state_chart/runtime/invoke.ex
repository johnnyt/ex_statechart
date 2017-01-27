defmodule StateChart.Runtime.Invoke do
  alias StateChart.Runtime
  use StateChart.Definition do
    field(:any, :type, 1)
    field(:any, :src, 2)
    field(:any, :id, 3)
    repeated(:any, :namelist, 4)
    field(:bool, :autoforward, 5)
    repeated(Runtime.Param, :params, 6)
    field(Runtime.Content, :content, 7)
    repeated(:any, :finalize, 8)
  end
end
