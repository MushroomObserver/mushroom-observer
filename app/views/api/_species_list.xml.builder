xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "species_list"
) do
  xml_string(xml, :title, object.title)
  xml_date(xml, :date, object.when)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  if object.location
    xml_detailed_object_old(xml, :location, object.location)
  else
    xml_undefined_location(xml, :location, object.where)
  end
  if !detail
    xml_minimal_object_old(xml, :owner, User, object.user_id)
  else
    xml_detailed_object_old(xml, :owner, object.user)
    xml.observations(number: object.observations.size) do
      object.observations.each do |obs|
        xml_minimal_object_old(xml, :observation, Observation, obs.id)
      end
    end
    xml.comments(number: object.comments.size) do
      object.comments.each do |comment|
        xml_detailed_object_old(xml, :comment, comment)
      end
    end
    xml.projects(number: object.projects.size) do
      object.projects.each do |proj|
        xml_minimal_object_old(xml, :project, Project, proj.id)
      end
    end
  end
end
