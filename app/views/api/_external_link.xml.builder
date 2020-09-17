xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "external_link"
) do
  xml_string(xml, :url, object.url)
  xml_string(xml, :external_site, object.site_name)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  if !detail
    xml_minimal_object(xml, :owner, User, object.user_id)
    xml_minimal_object(xml, :observation, Observation, object.observation_id)
  else
    xml_detailed_object(xml, :owner, object.user)
    xml_detailed_object(xml, :observation, object.observation)
  end
end
