# frozen_string_literal: true

json.id(object.id)
json.type("location_description")
json.location_id(object.location_id)
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
json.ecology(object.ecology.to_s.tpl_nodiv) if object.ecology.present?
json.species(object.species.to_s.tpl_nodiv) if object.species.present?
json.notes(object.notes.to_s.tpl_nodiv) if object.notes.present?
json.refs(object.refs.to_s.tpl_nodiv) if object.refs.present?
