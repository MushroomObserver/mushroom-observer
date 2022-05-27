# frozen_string_literal: true

json.id(object.id)
json.type("species_list")
json.title(object.title.to_s)
json.notes(object.notes.to_s.tpl_nodiv) if object.notes.present?
json.date(object.when)
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
if !detail
  json.owner_id(object.user_id)
  if object.location_id
    json.location_id(object.location_id)
  elsif object.where.present?
    json.location_name(object.where.to_s)
  end
else
  json.owner(json_user(object.user))
  if object.location
    json.location(json_location(object.location))
  elsif object.where.present?
    json.location_name(object.where.to_s)
  end
  json.comments(object.comments.map { |x| json_comment(x) }) \
    if object.comments.any?
end
