System.argv()
|> Enum.each(fn(input) ->

[test_dir, suite, cases, spec, name] = Path.split(input)
name = Path.basename(name, ".json")
out = Path.join([test_dir, suite, cases, spec, name <> "_test.exs"])
xml = Path.join([test_dir, suite, cases, spec, name <> ".scxml"])

module = Module.concat(["Test.StateChart.Suite", Macro.camelize(spec), Macro.camelize(name)])

bin = quote do
  defmodule unquote(module) do
    use Test.StateChart.Case

    @tag :suite
    @tag spec: unquote(spec)
    test unquote(name) do
      xml = unquote(File.read!(xml))
      %{"initialConfiguration" => conf,
        "events" => events} =
        unquote(input |> File.read!() |> Poison.decode!())

      test_scxml(xml, "", conf, events)
    end
  end
end
|> Macro.to_string()

File.write!(out, bin)

end)
