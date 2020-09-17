# frozen_string_literal: true

xml.tag!(
  tag,
  id: object.id,
  url: object.show_url,
  type: "image"
) do
  xml_date(xml, :date, object.when)
  xml_string(xml, :copyright_holder, object.copyright_holder)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_image_quality(xml, :quality, object.vote_cache)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_string(xml, :original_name, object.original_name) if check_permission(object)
  xml_integer(xml, :number_of_views, object.num_views)
  xml_datetime(xml, :last_viewed, object.last_view)
  xml_boolean(xml, :ok_for_export, true) if object.ok_for_export
  xml_string(xml, :license, object.license.display_name)
  xml_string(xml, :content_type, object.content_type)
  xml_integer(xml, :width, object.width)
  xml_integer(xml, :height, object.height)
  if !detail
    xml_minimal_object(xml, :owner, :user, object.user_id)
  else
    xml_detailed_object(xml, :owner, object.user)
    xml.files(number: Image.all_sizes.count + 1) do
      for size in Image.all_sizes + [:original]
        xml_image_file(xml, object, size)
      end
    end
    if object.observation_ids.any?
      xml.observations(number: object.observation_ids.count) do
        object.observation_ids.each do |observation_id|
          xml_minimal_object(xml, :observation, :observation, observation_id)
        end
      end
    end
  end
end
