# frozen_string_literal: true

json.id(object.id)
json.type("comment")
json.summary(object.summary.to_s.tl) if object.summary.present?
json.content(object.comment.to_s.tl_for_api) if object.comment.present?
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
json.object_type(object.target_type)
json.object_id(object.target_id)
if detail
  json.owner(json_user(object.user))
else
  json.owner_id(object.user_id)
end
