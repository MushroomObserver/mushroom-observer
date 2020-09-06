xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "external_link"
) do
  xml_string(xml, :url, object.url)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_minimal_object(xml, :observation, :observation, object.observation_id)
  if !detail
    xml_minimal_object(xml, :owner, :user, object.user_id)
    xml_minimal_object(xml, :external_site, :external_site,
                       object.external_site_id)
  else
    xml_detailed_object(xml, :owner, object.user)
    xml_detailed_object(xml, :external_site, object.external_site)
  end
end
