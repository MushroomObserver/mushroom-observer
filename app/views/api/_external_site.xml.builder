xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "external_site"
) do
  xml_string(xml, :name, object.name)
  if !detail
    xml_minimal_object_old(xml, :project, Project, object.project_id)
  else
    xml_detailed_object_old(xml, :project, object.project)
  end
end
