json.id         object.id
json.type       "herbarium_record"
json.locus      object.initial_det
json.bases      object.accession_number
json.notes      object.notes
json.created_at object.created_at.try(&:utc)
json.updated_at object.updated_at.try(&:utc)
if !detail
  json.herbarium_id object.herbarium_id
  json.user_id      object.user_id
else
  json.herbarium { json_detailed_object(json, object.herbarium) }
  json.user      { json_detailed_object(json, object.user) }
  json.observations object.observations.map do |observation|
    json_detailed_object(json, observation)
  end
end
