xml.tag!(tag,
  id: object.id,
  url: object.show_url,
  type: "observation"
) do
  xml_date(xml, :date, object.when)
  xml_latitude(xml, :latitude, object.public_lat)
  xml_longitude(xml, :longitude, object.public_long)
  xml_altitude(xml, :altitude, object.alt)
  xml_boolean(xml, :gps_hidden, object.gps_hidden)
  xml_boolean(xml, :specimen_available, object.specimen)
  xml_boolean(xml, :is_collection_location, object.is_collection_location)
  xml_confidence_level(xml, :confidence, object.vote_cache)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_integer(xml, :number_of_views, object.num_views)
  xml_datetime(xml, :last_viewed, object.last_view)
  unless object.notes.blank?
    notes_fields = object.notes.except(Observation.other_notes_key)
    other_notes  = object.notes_part_value(Observation.other_notes_key)
    if notes_fields.any?
      xml.notes_fields do
        notes_fields.each do |key, value|
          xml.notes_field do
            xml_string(xml, :key, key)
            xml_html_string(xml, :value, value.tpl_nodiv)
          end
        end
      end
    end
    xml_html_string(xml, :notes, other_notes.to_s.tpl_nodiv)
  end
  if !detail
    xml_minimal_object(xml, :owner, :user, object.user_id)
    xml_minimal_object(xml, :consensus_id, :name, object.name_id)
    xml_string(xml, :consensus_name, object.text_name)
    xml_minimal_location(xml, :location, object.location_id, object.where)
    xml_minimal_object(xml, :primary_image, :image, object.thumb_image_id)
  else
    xml_detailed_object(xml, :owner, object.user)
    xml_detailed_object(xml, :consensus_name, object.name)
    if object.namings.any?
      xml.namings(number: object.namings.length) do
        object.namings.each do |naming|
          xml_detailed_object(xml, :naming, naming)
        end
      end
    end
    if object.votes.any?
      xml.votes(number: object.votes.length) do
        object.votes.each do |vote|
          xml_detailed_object(xml, :vote, vote)
        end
      end
    end
    xml_detailed_location(xml, :location, object.location, object.where)
    object.images.each do |image|
      # Do it this way, else will not use eager-loaded image instance.
      next unless image.id == object.thumb_image_id
      xml_detailed_object(xml, :primary_image, image)
    end
    if object.images.length > 1
      xml.images(number: object.images.length - 1) do
        object.images.each do |image|
          next if image.id == object.thumb_image_id
          xml_detailed_object(xml, :image, image)
        end
      end
    end
    if object.comments.any?
      xml.comments(number: object.comments.length) do
        object.comments.each do |comment|
          xml_detailed_object(xml, :comment, comment)
        end
      end
    end
    if object.collection_numbers.any?
      xml.collection_numbers(number: object.collection_numbers.length) do
        object.collection_numbers.each do |collection_number|
          xml_detailed_object(xml, :collection_number, collection_number)
        end
      end
    end
    if object.herbarium_records.any?
      xml.herbarium_records(number: object.herbarium_records.length) do
        object.herbarium_records.each do |herbarium_record|
          xml_detailed_object(xml, :herbarium_record, herbarium_record)
        end
      end
    end
    if object.sequences.any?
      xml.sequences(number: object.sequences.length) do
        object.sequences.each do |sequence|
          xml_detailed_object(xml, :sequence, sequence)
        end
      end
    end
    if object.external_links.any?
      xml.external_links(number: object.external_links.length) do
        object.external_links.each do |external_link|
          xml_detailed_object(xml, :external_link, external_link)
        end
      end
    end
  end
end
