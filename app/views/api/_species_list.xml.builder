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
    xml_detailed_object(xml, :location, object.location)
  else
    xml_undefined_location(xml, :location, object.where)
  end
  if !detail
    xml_minimal_object(xml, :owner, User, object.user_id)
  else
    xml_detailed_object(xml, :owner, object.user)
    xml.observations(number: object.observation_ids.length) do
      for obs_id in object.observation_ids
        xml_minimal_object(xml, :observation, Observation, obs_id)
      end
    end
    xml.comments(number: object.comments.length) do
      for comment in object.comments
        xml_detailed_object(xml, :comment, comment)
      end
    end
    xml.projects(number: object.project_ids.length) do
      for proj_id in object.project_ids
        xml_minimal_object(xml, :project, Project, proj_id)
      end
    end
  end
end
