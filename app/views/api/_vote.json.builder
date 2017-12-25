json.id             object.id
json.type           "vote"
json.confidence     object.value
json.created_at     object.created_at.utc
json.updated_at     object.updated_at.utc
json.naming_id      object.naming_id
json.observation_id object.observation_id
if object.user == User.current or !object.anonymous?
  json.owner_id object.user_id
end
