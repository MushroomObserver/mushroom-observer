xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "collection_number"
) do
  xml_string(xml, :collector, object.name)
  xml_string(xml, :number, object.number)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  if !detail
    xml_minimal_object(xml, :user, :user, object.user_id)
  else
    xml_detailed_object(xml, :user, object.user)
    if object.observation_ids.any?
      xml.observations(number: object.observation_ids.count) do
        object.observation_ids.each do |observation_id|
          xml_minimal_object(xml, :observation, :observation, observation_id)
        end
      end
    end
  end
end
