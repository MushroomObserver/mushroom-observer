json.id         object.id
json.type       "sequence"
json.locus      object.locus
json.bases      object.bases
json.archive    object.archive
json.accession  object.accession
json.notes      object.notes.to_s.tpl_nodiv
json.created_at object.created_at.try(&:utc)
json.updated_at object.updated_at.try(&:utc)
if !detail
  json.observation_id object.observation_id
  json.user_id        object.user_id
else
  json.observation { json_detailed_object(json, object.observation) }
  json.user        { json_detailed_object(json, object.user) }
end
