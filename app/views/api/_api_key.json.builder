json.id         object.id
json.type       "api_key"
json.key        object.key.to_s
json.notes      object.notes.to_s.tpl_nodiv if object.notes.present?
json.created_at object.created_at.try(&:utc)
json.last_used  object.last_used.try(&:utc)
json.verified   object.verified.try(&:utc)
json.num_users  object.num_uses
