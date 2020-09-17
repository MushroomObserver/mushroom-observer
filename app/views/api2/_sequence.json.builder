# frozen_string_literal: true

json.id(object.id)
json.type("sequence")
json.locus(object.locus.to_s) if object.locus.present?
json.bases(object.bases.to_s) if object.bases.present?
json.archive(object.archive.to_s) if object.archive.present?
json.accession(object.accession.to_s) if object.accession.present?
json.notes(object.notes.to_s.tpl_nodiv) if object.notes.present?
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
json.observation_id(object.observation_id) if object.observation_id
if !detail
  json.user_id(object.user_id)
else
  json.user(json_user(object.user))
end
