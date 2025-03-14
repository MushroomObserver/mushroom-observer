# frozen_string_literal: true

json.id(object.id)
json.type("project")
json.title(object.title.to_s)
json.summary(object.summary.to_s.tl_for_api) if object.summary.present?
json.title(object.field_slip_prefix.to_s) if object.field_slip_prefix.present?
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
if detail
  json.creator(json_user(object.user))
  if object.comments.any?
    json.comments(object.comments.map { |x| json_comment(x) })
  end
else
  json.creator_id(object.user_id)
end
