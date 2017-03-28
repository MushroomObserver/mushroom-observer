json.id         object.id
json.type       "vote"
json.confidence object.value
json.created_at object.created_at
json.updated_at object.updated_at
if !detail
  json.owner_id       object.user_id if object.user == User.current or !object.anonymous?
  json.naming_id      object.naming_id
  json.observation_id object.observation_id
else
  json.owner       json_minimal_object(json, object.user) if object.user == User.current or !object.anonymous?
  json.naming      json_minimal_object(json, object.naming)
  json.observation json_minimal_object(json, object.observation)
end
