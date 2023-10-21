# frozen_string_literal: true

json.id(object.id)
json.type("name_description")
json.name_id(object.name_id)
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
json.number_of_views(object.num_views)
json.last_viewed(object.last_view.try(&:utc))
json.ok_for_export(object.ok_for_export ? true : false)
json.source_type(object.source_type.to_s)
json.source_name(object.source_name.to_s) if object.source_name.present?
json.license(object.license.try(&:display_name).to_s)
json.public(object.public ? true : false)
json.locale(object.locale.to_s)
json.gen_desc(object.gen_desc.to_s.tpl_nodiv) if object.gen_desc.present?
json.diag_desc(object.diag_desc.to_s.tpl_nodiv) if object.diag_desc.present?
json.distribution(object.distribution.to_s.tpl_nodiv) \
  if object.distribution.present?
json.habitat(object.habitat.to_s.tpl_nodiv) if object.habitat.present?
json.look_alikes(object.look_alikes.to_s.tpl_nodiv) \
  if object.look_alikes.present?
json.uses(object.uses.to_s.tpl_nodiv) if object.uses.present?
json.notes(object.notes.to_s.tpl_nodiv) if object.notes.present?
json.refs(object.refs.to_s.tpl_nodiv) if object.refs.present?
json.classification(object.classification.to_s.tpl_nodiv) \
  if object.classification.present?
