# frozen_string_literal: true

xml.tag!(
  tag,
  id: object.id,
  url: object.show_url,
  type: "location"
) do
  xml_string(xml, :name, object.text_name)
  xml_latitude(xml, :latitude_north, object.north)
  xml_latitude(xml, :latitude_south, object.south)
  xml_longitude(xml, :longitude_east, object.east)
  xml_longitude(xml, :longitude_west, object.west)
  xml_altitude(xml, :altitude_maximum, object.high)
  xml_altitude(xml, :altitude_minimum, object.low)
  xml_html_string(xml, :notes, object.notes.to_s.tpl_nodiv)
  xml_datetime(xml, :created_at, object.created_at)
  xml_datetime(xml, :updated_at, object.updated_at)
  xml_integer(xml, :number_of_views, object.num_views)
  xml_datetime(xml, :last_viewed, object.last_view)
  xml_boolean(xml, :ok_for_export, true) if object.ok_for_export
  if detail && object.comments.any?
    xml.comments(number: object.comments.count) do
      object.comments.each do |comment|
        xml_detailed_object(xml, :comment, comment)
      end
    end
  end
end
