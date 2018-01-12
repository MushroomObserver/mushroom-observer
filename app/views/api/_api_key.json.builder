json.id        object.id
json.type      "api_key"
json.key       object.key
json.notes     object.notes.to_s.tpl_nodiv
json.joined    object.created_at.try(&:utc)
json.verified  object.last_used.try(&:utc)
json.num_users object.num_uses
