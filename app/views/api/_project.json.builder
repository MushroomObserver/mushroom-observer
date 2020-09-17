json.id         object.id
json.type       "project"
json.title      object.title
json.created_at object.created_at.try(&:utc)
json.updated_at object.updated_at.try(&:utc)
json.summary    object.summary.to_s.tpl_nodiv
if !detail
  json.creator_id object.user_id
else
  json.creator { json_detailed_object(json, object.user) }
  json.admin_ids  object.admin_group.user_ids
  json.member_ids object.user_group.user_ids
end
