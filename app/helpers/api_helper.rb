# frozen_string_literal: true

#
#  = API Helpers
#
#  Methods available to API XML responses.
#
################################################################################

module ApiHelper
  def xml_boolean(xml, tag, val)
    str = val ? "true" : "false"
    xml.tag!(tag, type: "boolean", value: str)
  rescue StandardError
  end

  def xml_integer(xml, tag, val)
    str = begin
            "%d" % val
          rescue StandardError
            ""
          end
    xml.tag!(tag, str, type: "integer")
  rescue StandardError
  end

  def xml_float(xml, tag, val, places)
    str = begin
            "%.#{places}f" % val
          rescue StandardError
            ""
          end
    xml.tag!(tag, str, type: "float")
  rescue StandardError
  end

  def xml_string(xml, tag, val)
    if val.present?
      str = val.to_s
      xml.tag!(tag, str, type: "string", content_type: "text/plain")
    end
  rescue StandardError
  end

  def xml_html_string(xml, tag, val)
    if val.present?
      str = val.to_s
      xml.tag!(tag, str, type: "string", content_type: "text/html")
    end
  rescue StandardError
  end

  def xml_sql_string(xml, tag, val)
    if val.present?
      str = val.to_s
      xml.tag!(tag, str, type: "string", content_type: "application/x-sql")
    end
  rescue StandardError
  end

  def xml_date(xml, tag, val)
    if val
      str = begin
              val.api_date
            rescue StandardError
              ""
            end
      xml.tag!(tag, str, type: "date", format: "YYYY-MM-DD")
    end
  rescue StandardError
  end

  def xml_datetime(xml, tag, val)
    if val
      str = val.utc.api_time
      xml.tag!(tag, str, type: "date-time", format: "YYYY-MM-DD HH:MM:SS")
    end
  rescue StandardError
  end

  def xml_ellapsed_time(xml, tag, val)
    str = "%.4f" % val
    xml.tag!(tag, str, type: "float", units: "seconds")
  rescue StandardError
  end

  def xml_latitude(xml, tag, val)
    str = "%.4f" % val
    xml.tag!(tag, str, type: "float", units: "degrees north")
  rescue StandardError
  end

  def xml_longitude(xml, tag, val)
    str = "%.4f" % val
    xml.tag!(tag, str, type: "float", units: "degrees east")
  rescue StandardError
  end

  def xml_altitude(xml, tag, val)
    str = "%d" % val
    xml.tag!(tag, str, type: "integer", units: "meters")
  rescue StandardError
  end

  def xml_undefined_location(xml, tag, val)
    if User.current_location_format == :scientific
      val = Location.reverse_name(val)
    end
    xml.tag!(tag, val, type: "string")
  rescue StandardError
  end

  def xml_naming_reason(xml, tag, val)
    if val.notes.blank?
      xml.tag!(tag, category: val.label.l)
    else
      str = val.notes.to_s
      xml.tag!(tag, str, category: val.label.l)
    end
  end

  def xml_confidence_level(xml, tag, val)
    str = "%.2f" % val
    xml.tag!(tag, str, type: "float", range: "-3.0 to 3.0")
  rescue StandardError
  end

  def xml_image_quality(xml, tag, val)
    str = "%.2f" % val
    xml.tag!(tag, str, type: "float", range: "0.0 to 4.0")
  rescue StandardError
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

  def xml_minimal_object_old(xml, tag, model, id)
    if id.present?
      model = model.constantize unless model.is_a?(Class)
      url = begin
              model.show_url(id)
            rescue StandardError
              nil
            end
      if url
        xml.tag!(tag, id: id, url: url, type: model.type_tag.to_s)
      else
        xml.tag!(tag, id: id, type: model.type_tag.to_s)
      end
    end
  end

  def xml_detailed_object_old(xml, tag, object, detail = false)
    render_detailed_object(xml, object, detail, tag: tag)
  end

  def json_detailed_object(json, object, detail = false)
    render_detailed_object(json, object, detail, json: json)
  end

  def render_detailed_object(builder, object, detail, args)
    return unless object

    builder.target! << render(
      partial: object.class.type_tag.to_s,
      locals: args.merge(
        object: object,
        detail: detail
      )
    )
  end
end
