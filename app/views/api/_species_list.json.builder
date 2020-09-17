json.id         object.id
json.type       "species_list"
json.title      object.title
json.date       object.when
json.created_at object.created_at.try(&:utc)
json.updated_at object.updated_at.try(&:utc)
json.notes      object.notes.to_s.tpl_nodiv
if object.location
  json.location { json_detailed_object(json, object.location) }
else
  json.location_name object.where
end
if !detail
  json.owner_id object.user_id
else
  json.owner           { json_detailed_object(json, object.user) }
  json.observation_ids object.observation_ids
  json.comment_ids     object.comment_ids
  json.project_ids     object.project_ids
end
