# frozen_string_literal: true

#
#  = API Helpers
#
#  Methods available to API XML responses.
#
################################################################################

module ApiHelper
  include ApiInlineHelper

  def xml_boolean(xml, tag, val)
    str = val ? "true" : "false"
    xml.tag!(tag, type: "boolean", value: str)
  end

  def xml_integer(xml, tag, val)
    return if val.blank?
    return unless str = val.try(:to_i)

    xml.tag!(tag, str.to_s, type: "integer")
  end

  def xml_float(xml, tag, val, places)
    return if val.blank?
    return unless str = val.try(:round, places)

    xml.tag!(tag, str.to_s, type: "float")
  end

  def xml_string(xml, tag, val)
    return if val.blank?

    xml.tag!(tag, val.to_s, type: "string", content_type: "text/plain")
  end

  def xml_html_string(xml, tag, val)
    return if val.blank?

    xml.tag!(tag, val.to_s, type: "string", content_type: "text/html")
  end

  def xml_sql_string(xml, tag, val)
    return if val.blank?

    xml.tag!(tag, val.to_s, type: "string", content_type: "application/x-sql")
  end

  def xml_date(xml, tag, val)
    return if val.blank?
    return unless str = val.try(:api_date)

    xml.tag!(tag, str, type: "date", format: "YYYY-MM-DD")
  end

  def xml_datetime(xml, tag, val)
    return if val.blank?
    return unless str = val.try(:utc).try(:api_time)

    xml.tag!(tag, str, type: "date-time", format: "YYYY-MM-DD HH:MM:SS")
  end

  def xml_ellapsed_time(xml, tag, val)
    return if val.blank?
    return unless str = val.try(:round, 4)

    xml.tag!(tag, str.to_s, type: "float", units: "seconds")
  end

  def xml_latitude(xml, tag, val)
    return if val.blank?
    return unless str = val.try(:round, 4)

    xml.tag!(tag, str.to_s, type: "float", units: "degrees north")
  end

  def xml_longitude(xml, tag, val)
    return if val.blank?
    return unless str = val.try(:round, 4)

    xml.tag!(tag, str.to_s, type: "float", units: "degrees east")
  end

  def xml_altitude(xml, tag, val)
    return if val.blank?
    return unless str = val.try(:to_i)

    xml.tag!(tag, str.to_s, type: "integer", units: "meters")
  end

  def xml_naming_reason(xml, tag, val)
    if val.notes.blank?
      xml.tag!(tag, category: val.label.l)
    else
      xml.tag!(tag, val.notes.to_s, category: val.label.l)
    end
  end

  def xml_confidence_level(xml, tag, val)
    return if val.blank?
    return unless str = val.try(:round, 2)

    xml.tag!(tag, str.to_s, type: "float", range: "-3.0 to 3.0")
  end

  def xml_image_quality(xml, tag, val)
    return if val.blank?
    return unless str = val.try(:round, 2)

    xml.tag!(tag, str.to_s, type: "float", range: "0.0 to 4.0")
  end

  def xml_image_file(xml, image, size)
    url = image.send("#{size}_url")
    w, h = image.size(size)
    xml.file(
      url: url,
      content_type: (size == :original ? image.content_type : "image/jpeg"),
      width: w,
      height: h,
      size: size.to_s
    )
  end

  def xml_minimal_object(xml, tag, type, id)
    return if id.blank?

    xml.tag!(tag, id: id, type: type.to_s)
  end

  def xml_detailed_object(xml, tag, object)
    return if object.blank?

    type = object.type_tag.to_s
    xml.tag!(tag, id: object.id, type: type) do |inner_xml|
      send("xml_#{type}", inner_xml, object)
    end
  end

  def xml_minimal_location(xml, tag, location_id, where)
    if location_id
      xml.tag!(tag, id: location_id, name: where, type: "location")
    else
      xml.tag!(tag, name: where, type: "location")
    end
  end

  def xml_detailed_location(xml, tag, location, where)
    if location
      xml_detailed_object(xml, tag, location)
    else
      xml.tag!(tag, name: where, type: "location")
    end
  end
end
