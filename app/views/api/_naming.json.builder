json.id             object.id
json.type           "naming"
json.confidence     object.vote_cache
json.created_at     object.created_at.try(&:utc)
json.updated_at     object.updated_at.try(&:utc)
json.name           { json_detailed_object(json, object.name) }
json.owner_id       object.user_id
json.observation_id object.observation_id
if detail
  json.votes object.votes.map do |vote|
    json_detailed_object(json, vote)
  end
end
reasons = object.get_reasons.select(&:used?)
if reasons.any?
  json.reasons reasons.map do |reason|
    {
      type:  reason.label.l,
      notes: reason.notes.to_s.tpl_nodiv
    }
  end
end
