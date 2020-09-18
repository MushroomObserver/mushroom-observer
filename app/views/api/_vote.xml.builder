xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "vote"
) do
  xml_confidence_level(xml, :confidence, object.value)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_minimal_object_old(xml, :naming, Naming, object.naming_id)
  xml_minimal_object_old(xml, :observation, Observation, object.observation_id)
  if object.user == User.current or !object.anonymous?
    xml_minimal_object_old(xml, :owner, User, object.user_id)
  end
end
