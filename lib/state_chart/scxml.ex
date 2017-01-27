defmodule StateChart.SCXML do
  import __MODULE__.Utils
  alias StateChart.{Document,Runtime}
  alias Document.{Analyzer,State,Transition}

  def parse(xml, opts \\ %{models: %{}})
  def parse(xml, opts) when is_binary(xml) do
    root = __MODULE__.Parser.parse(xml)
    parse(root, opts)
  end
  def parse(root, opts) do
    {doc, _} = root(nil, root, [], opts)
    doc
  end

  defchild root, [:scxml]

  defp scxml(parent_doc, el, _, opts) do
    attrs = fetch_attrs!(el, %{
      "initial" => string() |> space_list(),
      "name" => string(),
      "xmlns" => "http://www.w3.org/2005/07/scxml" |> required(),
      "version" => 1.0 |> required(),
      "datamodel" => datamodel(opts) |> default("null"),
      "binding" => enum(["early", "late"]) |> default("early")
    }) |> Map.drop(["xmlns", "version"])

    doc = %{Document.new(
      name: attrs["name"]
    ) |
      datamodel: attrs["datamodel"],
      initial: attrs["initial"]
    }

    {_, doc} = traverse(doc, el, [], opts, &scxml_child/4)

    doc = Analyzer.finalize(doc, opts)

    {doc, parent_doc}
  end
  defchild scxml_child, [
    :state, :parallel, :final, :datamodel, :script
  ]

  defp state(doc, el, ancestors, opts) do
    state = fetch_attrs!(el, %{
      "id" => string(),
      "initial" => string() |> space_list(),
      ref: Analyzer.ref(doc),
      ancestors: ancestors
    }) |> State.new()

    {doc, state, ancestors} = Analyzer.on_enter(doc, state, ancestors)
    {children, doc} = traverse(doc, el, ancestors, opts, &state_child/4)
    Analyzer.on_exit(doc, state, children)
  end
  defchild state_child, [
    :onentry, :onexit, :transition, :initial, :state, :parallel, :final, :history, :datamodel, :invoke
  ]

  defp parallel(doc, el, ancestors, opts) do
    state = fetch_attrs!(el, %{
      "id" => string(),
      type: :parallel,
      ref: Analyzer.ref(doc),
      ancestors: ancestors
    }) |> State.new()

    {doc, state, ancestors} = Analyzer.on_enter(doc, state, ancestors)
    {children, doc} = traverse(doc, el, ancestors, opts, &parallel_child/4)
    Analyzer.on_exit(doc, state, children)
  end
  defchild parallel_child, [
    :onentry, :onexit, :transition, :state, :parallel, :history, :datamodel, :invoke
  ]

  defp transition(doc, el, ancestors, opts) do
    transition = fetch_attrs!(el, %{
      "event" => event_descriptor(),
      "cond" => expr(doc) |> default(true),
      "target" => string() |> space_list(),
      "type" => enum(["internal", "external"]) |> default("external")
    }) |> Transition.new()

    {children, doc} = traverse(doc, el, ancestors, opts, &executable_child/4)
    {%{transition | on_transition: children}, doc}
  end

  defp initial(doc, el, ancestors, opts) do
    state = %{
      type: :initial,
      ref: Analyzer.ref(doc),
      ancestors: ancestors
    } |> State.new()

    {doc, state, ancestors} = Analyzer.on_enter(doc, state, ancestors)
    {children, doc} = traverse(doc, el, ancestors, opts, &history_child/4)
    state = %{state | transitions: children}
    Analyzer.on_exit(doc, state, [])
  end
  defchild initial_child, [:transition]

  defp final(doc, el, ancestors, opts) do
    state = fetch_attrs!(el, %{
      "id" => string(),
      type: :final,
      ref: Analyzer.ref(doc),
      ancestors: ancestors
    }) |> State.new()

    {doc, state, ancestors} = Analyzer.on_enter(doc, state, ancestors)
    {children, doc} = traverse(doc, el, ancestors, opts, &final_child/4)
    Analyzer.on_exit(doc, state, children)
  end
  defchild final_child, [
    :onentry, :onexit, :donedata
  ]

  defp onentry(doc, el, ancestors, opts) do
    {children, doc} = traverse(doc, el, ancestors, opts, &executable_child/4)
    content = {:on_entry, children}
    {content, doc}
  end

  defp onexit(doc, el, ancestors, opts) do
    {children, doc} = traverse(doc, el, ancestors, opts, &executable_child/4)
    content = {:on_exit, children}
    {content, doc}
  end

  defp history(doc, el, ancestors, opts) do
    attrs = fetch_attrs!(el, %{
      "id" => string(),
      "type" => enum(["deep", "shallow"])
    })

    state = %{
      id: attrs["id"],
      history_type: attrs["type"],
      type: :history,
      ref: Analyzer.ref(doc),
      ancestors: ancestors
    } |> State.new()

    {doc, state, ancestors} = Analyzer.on_enter(doc, state, ancestors)
    {children, doc} = traverse(doc, el, ancestors, opts, &history_child/4)
    Analyzer.on_exit(doc, state, children)
  end

  defchild history_child, [:transition]

  # Section 4

  defchild executable_child, [
    :raise, :if, :foreach, :log, :assign, :script, :send, :cancel
  ], :execute

  defp raise(doc, el, _ancestors, _opts) do
    ex = fetch_attrs!(el, %{
      "event" => string() |> required()
    }) |> Runtime.Raise.new()
    {ex, doc}
  end

  defp if(doc, el, ancestors, opts) do
    {children, doc} = traverse(doc, el, ancestors, opts, &if_child/4)
    # TODO split if_else and else
    {children, e} = {children, []}
    ex = fetch_attrs!(el, %{
      "cond" => expr(doc) |> required(),
      :children => children,
      :else => e
    }) |> Runtime.If.new()
    {ex, doc}
  end
  defchild if_child, [
    :raise, :if, :elseif, :else, :foreach, :log, :assign, :script, :send, :cancel
  ], :execute

  defp elseif(doc, el, _ancestors, _opts) do
    %{"cond" => c} = fetch_attrs!(el, %{
      "cond" => expr(doc) |> required()
    })
    {{:else_if, c}, doc}
  end

  defp else_(doc, _el, _ancestors, _opts) do
    {:else, doc}
  end

  defp foreach(doc, el, ancestors, opts) do
    attrs = fetch_attrs!(el, %{
      "array" => expr(doc) |> required(),
      "item" => var(doc) |> required(),
      "index" => var(doc)
    })

    doc = push_scope(doc, MapSet.new([attrs["index"],attrs["index"]]))
    {children, doc} = traverse(doc, el, ancestors, opts, &executable_child/4)
    doc = pop_scope(doc)

    foreach = attrs
    |> Map.put("children", children)
    |> Runtime.Foreach.new()

    {foreach, doc}
  end

  defp log(doc, el, _ancestors, _opts) do
    ex = fetch_attrs!(el, %{
      "label" => string() |> default(""),
      "expr" => expr(doc)
    }) |> Runtime.Log.new()
    {ex, doc}
  end

  # Section 5

  defp datamodel(doc, el, ancestors, opts) do
    {_, doc} = traverse(doc, el, ancestors, opts, &datamodel_child/4)
    {nil, doc}
  end
  defchild datamodel_child, [:data]

  defp data(doc, el, _ancestors, _opts) do
    _data = fetch_attrs!(el, %{
      "id" => string() |> required(),
      "src" => uri(),
      "expr" => expr(doc)
    })
    # TODO traverse children
    # {_, doc} = traverse(doc, el, ancestors, opts, &data_child/3)
    {nil, doc}
  end

  defp assign(doc, el, _ancestors, _opts) do
    _data = fetch_attrs!(el, %{
      "location" => path_expr(doc) |> required(),
      "expr" => expr(doc)
    })
    # TODO traverse children
    {nil, doc}
  end

  defp donedata(doc, el, ancestors, opts) do
    {children, doc} = traverse(doc, el, ancestors, opts, &donedata_child/4)
    # TODO
    {nil, doc}
  end
  defchild donedata_child, [:content, :param]

  defp content(doc, el, _ancestors, _opts) do
    _data = fetch_attrs!(el, %{
      "expr" => expr(doc)
    })
    # TODO traverse children
    {nil, doc}
  end

  defp param(doc, el, _ancestors, _opts) do
    _data = fetch_attrs!(el, %{
      "name" => string(),
      "expr" => expr(doc),
      "location" => path_expr(doc)
    })
    # TODO traverse children
    {nil, doc}
  end

  defp script(doc, el, _ancestors, _opts) do
    _data = fetch_attrs!(el, %{
      "src" => uri()
    })
    # TODO possibly get children
    {nil, doc}
  end

  # Section 6

  defp send(doc, el, ancestors, opts) do
    attrs = fetch_attrs!(el, %{
      "event" => string(),
      "eventexpr" => expr(doc),
      "target" => uri(),
      "targetexpr" => expr(doc),
      "type" => string(),
      "typeexpr" => expr(doc),
      "id" => string(),
      "idlocation" => path_expr(doc),
      "delay" => delay_spec(),
      "delayexpr" => delay_expr(doc),
      "namelist" => expr(doc) |> space_list()
    })
    # TODO check attrs
    {children, doc} = traverse(doc, el, ancestors, opts, &send_child/4)
    {nil, doc}
  end
  defchild send_child, [:content, :param]

  defp cancel(doc, el, _ancestors, _opts) do
    attrs = fetch_attrs!(el, %{
      "sendid" => string(),
      "sendidexpr" => expr(doc)
    })
    {nil, doc}
  end

  defp invoke(doc, el, ancestors, opts) do
    attrs = fetch_attrs!(el, %{
      "type" => uri(),
      "typeexpr" => uri_expr(doc),
      "src" => uri(),
      "srcexpr" => uri_expr(doc),
      "id" => string(),
      "idlocation" => path_expr(doc),
      "namelist" => expr(doc) |> space_list(),
      "autoforward" => boolean() |> default(false)
    })
    # TODO check attrs
    {children, doc} = traverse(doc, el, ancestors, opts, &invoke_child/4)
    {nil, doc}
  end
  defchild invoke_child, [:param, :finalize, :content]

  defp finalize(doc, el, ancestors, opts) do
    # TODO
    {children, doc} = traverse(doc, el, ancestors, opts, &executable_child/4)
    {nil, doc}
  end

  defp event_descriptor() do
    fn(value) ->
      Regex.split(~r/\s+/, value)
      |> Enum.reduce([], fn
        ("*", _acc) ->
          nil
        (_, nil) ->
          nil
        (event, acc) ->
          [event | acc]
      end)
      |> case do
        nil ->
          []
        acc ->
          :lists.reverse(acc)
      end
    end
  end
end
