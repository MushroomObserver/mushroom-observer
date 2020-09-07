xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "api_key"
) do
  xml_string(xml, :key, object.key)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_date(xml, :created_at, object.created_at)
  xml_date(xml, :last_used, object.last_used)
  xml_date(xml, :verified, object.verified)
  xml_integer(xml, :num_uses, object.num_uses)
end
