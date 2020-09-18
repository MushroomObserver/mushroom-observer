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
    xml_minimal_object_old(xml, :user, User, object.user_id)
  else
    xml_detailed_object_old(xml, :user, object.user)
    xml.observations(number: object.observations.length) do
      object.observations.each do |observation|
        xml_detailed_object_old(xml, :observation, observation)
      end
    end
  end
end
