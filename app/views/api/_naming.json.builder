json.id         object.id
json.type       "naming"
json.confidence object.vote_cache
json.created_at object.created_at
json.updated_at object.updated_at
reasons = object.get_reasons.select(&:used?)
if reasons.any?
  json.reasons reasons.map do |reason|
    {
      type:  reason.label.l,
      notes: reason.notes.to_s
    }
  end
end
json.name json_detailed_object(json, object.name)
if !detail
  json.owner_id       object.user_id
  json.observation_id object.observation_id
else
  json.owner       json_detailed_object(json, object.user)
  json.observation json_detailed_object(json, object.observation)
  json.votes object.votes.map do |vote|
    json_detailed_object(json, vote)
  end
end
