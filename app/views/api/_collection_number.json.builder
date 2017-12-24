json.id         object.id
json.type       "collection_number"
json.collector  object.name
json.number     object.number
json.created_at object.created_at.utc
json.updated_at object.updated_at.utc
if !detail
  json.user_id  object.user_id
else
  json.user { json_detailed_object(json, object.user) }
  json.observations object.observations.map do |observation|
    json_detailed_object(json, observation)
  end
end
