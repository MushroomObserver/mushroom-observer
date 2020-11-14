# frozen_string_literal: true

xml.tag!(
  tag,
  id: object.id,
  url: object.show_url,
  type: "herbarium_record"
) do
  xml_string(xml, :initial_determination, object.initial_det)
  xml_string(xml, :accession_number, object.accession_number)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  if !detail
    xml_minimal_object(xml, :herbarium, :herbarium, object.herbarium_id)
    xml_minimal_object(xml, :user, :user, object.user_id)
  else
    xml_detailed_object(xml, :herbarium, object.herbarium)
    xml_detailed_object(xml, :user, object.user)
    if object.observations.any?
      xml.observations(number: object.observations.length) do
        object.observations.each do |observation|
          xml_minimal_object(xml, :observation, :observation, observation.id)
        end
      end
    end
  end
end
