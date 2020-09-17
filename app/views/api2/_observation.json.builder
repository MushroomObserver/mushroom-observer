# frozen_string_literal: true

json.id(object.id)
json.type("observation")
json.date(object.when)
json.latitude(object.public_lat if object.lat.present?
json.longitude(object.public_long if object.long.present?
json.altitude(object.alt if object.alt.present?
json.gps_hidden(object.gps_hidden ? true : false)
json.specimen_available(object.specimen ? true : false)
json.is_collection_location(object.is_collection_location ? true : false)
json.confidence(object.vote_cache if object.vote_cache.present?
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
json.number_of_views(object.num_views)
json.last_viewed(object.last_view.try(&:utc))
if object.notes.present?
  notes_fields = object.notes.except(Observation.other_notes_key)
  other_notes  = object.notes_part_value(Observation.other_notes_key)
  notes_fields.each do |key, val|
    val.replace(val.to_s.tpl_nodiv)
    notes_fields.delete_key(key) if val.blank?
  end
  json.notes_fields(notes_fields) if notes_fields.any?
  json.notes(other_notes.to_s.tpl_nodiv) if other_notes.present?
end
if !detail
  json.owner_id(object.user_id)
  json.consensus_id(object.name_id) if object.name_id
  json.consensus_name(object.text_name) if object.text_name.present?
  json.location_id(object.location_id) if object.location_id
  json.location_name(object.where) if object.where.present?
  json.primary_image_id(object.thumb_image_id) if object.thumb_image_id
else
  json.owner(json_user(object.user))
  json.consensus(json_name(object.name)) if object.name
  if object.namings.any?
    json.namings(object.namings.map { |x| json_naming(x) })
  end
  if object.votes.any?
    json.votes(object.votes.map { |x| json_vote(x) })
  end
  if object.location
    json.location(json_location(object.location))
  else
    json.location_name(object.where) if object.where.present?
  end
  other_images = []
  object.images.each do |image|
    # Do it this way, else will not use eager-loaded image instance.
    if image.id == object.thumb_image_id
      json.primary_image json_image(image)
    else
      other_images << image
    end
  end
  if other_images.any?
    json.images(other_images.map { |x| json_image(x) })
  end
  if object.comments.any?
    json.comments(object.comments.map { |x| json_comment(x) })
  end
  if object.collection_numbers.any?
    json.collection_numbers(object.collection_numbers.
                            map { |x| json_collection_number(x) })
  end
  if object.herbarium_records.any?
    json.herbarium_records(object.herbarium_records.
                           map { |x| json_herbarium_record(x) })
  end
  if object.sequences.any?
    json.sequences(object.sequences.map { |x| json_sequence(x) })
  end
  if object.external_links.any?
    json.external_links(object.external_links.map { |x| json_external_link(x) })
  end
end
