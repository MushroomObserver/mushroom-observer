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
  if !detail
    xml_minimal_object_old(xml, :observation, Observation,
                           object.observation_id)
    xml_minimal_object_old(xml, :user, User, object.user_id)
  else
    xml_detailed_object_old(xml, :observation, object.observation)
    xml_detailed_object_old(xml, :user, object.user)
  end
end
