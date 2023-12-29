# frozen_string_literal: true

xml.tag!(
  tag,
  id: object.id,
  url: object.show_url,
  type: "external_site"
) do
  xml_string(xml, :name, object.name)
  if detail
    xml_detailed_object(xml, :project, object.project)
  else
    xml_minimal_object(xml, :project, :project, object.project_id)
  end
end
