# frozen_string_literal: true

xml.tag!(
  tag,
  id: object.id,
  url: object.show_url,
  type: "field_slip"
) do
  xml_string(xml, :code, object.code)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_minimal_object(xml, :observation, :observation, object.observation_id)
  if detail
    xml_detailed_object(xml, :project, object.project)
    xml_detailed_object(xml, :user, object.user)
  else
    xml_minimal_object(xml, :project, :project, object.project_id)
    xml_minimal_object(xml, :user, :user, object.user_id)
  end
end
