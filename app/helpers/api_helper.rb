# encoding: utf-8
#
#  = API Helpers
#
#  Methods available to API XML responses.
#
################################################################################

module ApiHelper
  def xml_boolean(xml, tag, val)
    str = val ? 'true' : 'false'
    xml.send(tag, :type => 'boolean', :value => str)
  rescue
  end

  def xml_integer(xml, tag, val)
    str = '%d' % val rescue ''
    xml.send(tag, str, :type => 'integer')
  rescue
  end

  def xml_float(xml, tag, val, places)
    str = "%.#{places}f" % val rescue ''
    xml.send(tag, str, :type => 'float')
  rescue
  end

  def xml_string(xml, tag, val)
    if !val.blank?
      str = val.to_s
      xml.send(tag, str, :type => 'string', :content_type => 'text/plain')
    end
  rescue
  end

  def xml_html_string(xml, tag, val)
    if !val.blank?
      str = val.to_s
      xml.send(tag, str, :type => 'string', :content_type => 'text/html')
    end
  rescue
  end

  def xml_sql_string(xml, tag, val)
    if !val.blank?
      str = val.to_s
      xml.send(tag, str, :type => 'string', :content_type => 'application/x-sql')
    end
  rescue
  end

  def xml_date(xml, tag, val)
    str = val.api_date rescue ''
    xml.send(tag, str, :type => 'date', :format => 'YYYY-MM-DD')
  rescue
  end

  def xml_datetime(xml, tag, val)
    str = val.api_time
    xml.send(tag, str, :type => 'date-time', :format => 'YYYY-MM-DD HH:MM:SS')
  rescue
  end

  def xml_ellapsed_time(xml, tag, val)
    str = '%.4f' % val
    xml.send(tag, str, :type => 'float', :units => 'seconds')
  rescue
  end

  def xml_latitude(xml, tag, val)
    str = '%.4f' % val
    xml.send(tag, str, :type => 'float', :units => 'degrees north')
  rescue
  end

  def xml_longitude(xml, tag, val)
    str = '%.4f' % val
    xml.send(tag, str, :type => 'float', :units => 'degrees east')
  rescue
  end

  def xml_altitude(xml, tag, val)
    str = '%d' % val
    xml.send(tag, str, :type => 'integer', :units => 'meters')
  rescue
  end

  def xml_undefined_location(xml, tag, val)
    if @user && @user.location_format == :scientific
      val = Location.reverse_name(val)
    end
    xml.send(tag, val, :type => 'string')
  rescue
  end

  def xml_naming_reason(xml, tag, val)
    if val.notes.blank?
      xml.send(tag, :category => val.label.l)
    else
      str = val.notes.to_s
      xml.send(tag, str, :category => val.label.l)
    end
  end

  def xml_confidence_level(xml, tag, val)
    str = '%.2f' % val
    xml.send(tag, str, :type => 'float', :range => '-3.0 to 3.0')
  rescue
  end

  def xml_image_quality(xml, tag, val)
    str = '%.2f' % val
    xml.send(tag, str, :type => 'float', :range => '0.0 to 4.0')
  rescue
  end

  def xml_image_file(xml, image, size)
    url = image.send("#{size}_url")
    w, h = image.size(size)
    xml.file(
      :url => url,
      :content_type => (size == :original ? image.content_type : 'image/jpeg'),
      :width => w,
      :height => h,
      :size => size.to_s
    )
  end

  def xml_minimal_object(xml, tag, model, id)
    unless id.blank?
      model = model.constantize unless model.is_a?(Class)
      url = model.show_url(id) rescue nil
      if url
        xml.send(tag, :id => id, :url => url, :type => model.type_tag.to_s)
      else
        xml.send(tag, :id => id, :type => model.type_tag.to_s)
      end
    end
  end

  def xml_detailed_object(xml, tag, object, detail=false)
    if object
      xml.target! << render(
        :partial => object.class.type_tag.to_s, 
        :locals => {
          :tag => tag,
          :object => object,
          :detail => detail,
        }
      )
    end
  end
end
