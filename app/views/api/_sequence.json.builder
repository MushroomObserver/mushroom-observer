json.id              object.id
  if !detail
    json.observation_id object.observation_id
    json.user_id        object.user_id
  else
    json.observation    { json_detailed_object(json, object.observation) }
    json.user           { json_detailed_object(json, object.user) }
  end
json.locus              object.locus
json.archive            object.archive
json.accession          object.accession
json.bases              object.bases
json.notes              object.notes
