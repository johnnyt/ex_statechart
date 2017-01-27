defmodule StateChart do
  defmodule Event do
    defstruct [
      :name,
      :type,
      :timestamp,
      :origin,
      :origin_type,
      :send_id,
      :invoke_id,
      :data
    ]

    def new(info \\ %{}) do
      info
      |> Enum.reduce(%__MODULE__{}, &handle_kv/2)
    end

    defp handle_kv({_, nil}, acc), do: acc
    defp handle_kv({k, v}, acc) when k in [:name, "name"] do
      %{acc | name: v}
    end
    defp handle_kv({k, v}, acc) when k in [:type, "$type", "type"] do
      %{acc | type: v}
    end
    defp handle_kv({k, v}, acc) when k in [:data, "data", "data"] do
      %{acc | type: v}
    end
  end
end
