defmodule StateChart.SCXML.Parser do
  require Record

  records = [
    :xmlDecl,
    :xmlAttribute,
    :xmlNamespace,
    :xmlNsNode,
    :xmlElement,
    :xmlText,
    :xmlComment,
    :xmlPI,
    :xmlDocument,
    :xmlObj
  ]

  for tag <- records do
    name = tag |> to_string() |> Macro.underscore()
    fields = Record.extract(tag, from_lib: "xmerl/include/xmerl.hrl")
    Record.defrecord String.to_atom(name), tag, fields
  end

  # TODO replace with html_parser + xmerl mode
  def parse(xml) when is_binary(xml) do
    xml
    |> to_charlist()
    |> parse()
  end
  def parse(xml) do
    {doc, _} = :xmerl_scan.string(xml)
    doc
    |> to_binary()
  end

  # TODO this'll go away when we move parsers
  defp to_binary({tag, pos}) when is_integer(pos) do
    {Atom.to_string(tag), pos}
  end
  defp to_binary(xml_decl() = d) do
    # TODO
    d
  end
  defp to_binary(xml_attribute(
    name: name, expanded_name: expanded_name, nsinfo: nsinfo, namespace: namespace,
    parents: parents, pos: pos, language: language, value: value, normalized: normalized
  )) do
    xml_attribute(
      name: Atom.to_string(name),
      expanded_name: to_binary_list(expanded_name),
      nsinfo: format_nsinfo(nsinfo),
      namespace: to_binary_list(namespace),
      parents: to_binary_list(parents),
      pos: pos,
      language: to_binary_list(language),
      value: :erlang.list_to_binary(value),
      normalized: normalized
    )
  end
  defp to_binary(xml_namespace(default: default, nodes: nodes)) do
    xml_namespace(
      default: case default do
        [] -> []
        _ -> Atom.to_string(default)
      end,
      nodes: Enum.map(nodes, fn({t, u}) -> {to_string(t), to_string(u)} end)
    )
  end
  defp to_binary(xml_ns_node() = d) do
    # TODO
    d
  end
  defp to_binary(
    xml_element(
      name: name, expanded_name: expanded_name, nsinfo: nsinfo, namespace: namespace,
      parents: parents, pos: pos, attributes: attributes, content: content, language: language,
      xmlbase: xmlbase, elementdef: elementdef
    )
  ) do
    xml_element(
      name: Atom.to_string(name),
      expanded_name: Atom.to_string(expanded_name),
      nsinfo: format_nsinfo(nsinfo),
      namespace: to_binary(namespace),
      parents: to_binary_list(parents),
      pos: pos,
      attributes: to_binary_list(attributes),
      content: to_binary_list(content),
      language: to_binary_list(language),
      xmlbase: to_string(xmlbase),
      elementdef: elementdef
    )
  end
  defp to_binary(xml_text(
    parents: parents, pos: pos, language: language, value: value, type: type
  )) do
    xml_text(
      parents: to_binary_list(parents),
      pos: pos,
      language: to_binary_list(language),
      value: :erlang.list_to_binary(value),
      type: type
    )
  end
  defp to_binary(xml_comment(
    parents: parents, pos: pos, language: language, value: value
  )) do
    xml_comment(
      parents: to_binary_list(parents),
      pos: pos,
      language: to_binary_list(language),
      value: :erlang.list_to_binary(value)
    )
  end
  defp to_binary(xml_pi() = d) do
    # TODO
    d
  end
  defp to_binary(xml_document(content: content)) do
    xml_document(content: to_binary(content))
  end
  defp to_binary(xml_obj() = d) do
    # TODO
    d
  end

  defp to_binary_list(l) do
    Enum.map(l, &to_binary/1)
  end

  defp format_nsinfo([]) do
    []
  end
  defp format_nsinfo({parent, current}) do
    {to_string(parent), to_string(current)}
  end
end
