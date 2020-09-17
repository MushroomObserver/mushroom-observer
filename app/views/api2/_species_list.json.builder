# frozen_string_literal: true

json.id(object.id)
json.type("species_list")
json.title(object.title.to_s)
json.notes(object.notes.to_s.tpl_nodiv) if object.notes.present?
json.date(object.when)
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
if !detail
  if object.location_id
    json.location_id(object.location_id)
  else
    json.location_name(object.where.to_s) if object.where.present?
  end
  json.owner_id(object.user_id)
else
  if object.location
    json.location(json_location(object.location))
  else
    json.location_name(object.where.to_s) if object.where.present?
  end
  json.owner(json_user(object.user))
  if object.comments.any?
    json.comments(object.comments.map { |x| json_comment(x) })
  end
end
