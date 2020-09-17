xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "sequence"
) do
  xml_string(xml, :locus, object.locus.truncate(object.locus_width))
  # Treat bases as html to preserve newlines and opening ">"
  xml_html_string(xml, :bases, object.bases.tp)
  xml_string(xml, :archive, object.archive)
  xml_string(xml, :accession, object.accession)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_minimal_object(xml, :observation, :observation, object.observation_id)
  if !detail
    xml_minimal_object(xml, :user, :user, object.user_id)
  else
    xml_detailed_object(xml, :user, object.user)
  end
end
