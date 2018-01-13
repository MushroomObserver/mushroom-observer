json.id                     object.id
json.type                   "observation"
json.date                   object.when
json.latitude               object.lat
json.longitude              object.long
json.altitude               object.alt
json.specimen_available     object.specimen ? true : false
json.is_collection_location object.is_collection_location ? true : false
json.confidence             object.vote_cache
unless object.notes.blank?
  notes_fields = object.notes.except(Observation.other_notes_key)
  other_notes  = object.notes_part_value(Observation.other_notes_key)
  notes_fields.each do |key, val|
    val.replace(val.to_s.tpl_nodiv)
  end
  json.notes_fields         notes_fields
  json.notes                other_notes.to_s.tpl_nodiv
end
json.created_at             object.created_at.try(&:utc)
json.updated_at             object.updated_at.try(&:utc)
json.number_of_views        object.num_views
json.last_viewed            object.last_view.try(&:utc)
json.owner                  { json_detailed_object(json, object.user) }
json.consensus              { json_detailed_object(json, object.name) }
if object.location
  json.location { json_detailed_object(json, object.location) }
else
  json.location_name object.where
end
if detail
  json.collection_numbers object.collection_numbers.map do |collection_number|
    json_detailed_object(json, collection_number)
  end
  json.herbarium_records object.herbarium_records.map do |herbarium_record|
    json_detailed_object(json, herbarium_record)
  end
  json.sequences object.sequences.map do |sequence|
    json_detailed_object(json, sequence)
  end
  json.namings object.namings.map do |naming|
    json_detailed_object(json, naming, true)
  end
  other_images = []
  object.images.each do |image|
    # Do it this way, else will not use eager-loaded image instance.
    if image.id == object.thumb_image_id
      json.primary_image { json_detailed_object(json, image) }
    else
      other_images << image
    end
  end
  json.images other_images.map do |image|
    json_detailed_object(json, image)
  end
  json.comments object.comments.map do |comment|
    json_detailed_object(json, comment)
  end
end
