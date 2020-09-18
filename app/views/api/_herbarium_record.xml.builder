xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "herbarium_record"
) do
  xml_string(xml, :initial_det, object.initial_det)
  xml_string(xml, :accession_number, object.accession_number)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  if !detail
    xml_minimal_object_old(xml, :herbarium, Herbarium, object.herbarium_id)
    xml_minimal_object_old(xml, :user, User, object.user_id)
  else
    xml_detailed_object_old(xml, :herbarium, object.herbarium)
    xml_detailed_object_old(xml, :user, object.user)
    xml.observations(number: object.observations.length) do
      object.observations.each do |observation|
        xml_detailed_object_old(xml, :observation, observation)
      end
    end
  end
end
