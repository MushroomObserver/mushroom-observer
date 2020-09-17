xml.tag!(tag,
  id: object.id,
  url: object.url,
  type: "license"
) do
  xml_string(xml, :name, object.display_name)
  xml_boolean(xml, :deprecated, true) if object.deprecated
end
