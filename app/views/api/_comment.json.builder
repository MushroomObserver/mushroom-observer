json.id         object.id
json.type       "comment"
json.summary    object.summary.to_s.tl
json.content    object.comment.to_s.tpl_nodiv
json.created_at object.created_at.utc
json.updated_at object.updated_at.utc
if !detail
  json.owner_id    object.user_id
  json.object_type object.target_type
  json.object_id   object.target_id
else
  json.owner  { json_detailed_object(json, object.user) }
  json.object { json_detailed_object(json, object.target) }
end
