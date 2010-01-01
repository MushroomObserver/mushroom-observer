module ApiHelper
  def xml_date(x);     !x ? nil : x.strftime('%Y-%m-%d');          end
  def xml_time(x);     !x ? nil : x.strftime('%H:%M:%S');          end
  def xml_datetime(x); !x ? nil : x.strftime('%Y-%m-%d %H:%M:%S'); end

  def render_xml_partial(xml, partial, args={})
    args[:partial] = partial.to_s
    xml.target! << render(args)
  end
end

class MoApiException < StandardError
  attr_accessor :code, :msg, :fatal

  def initialize(args={})
    self.code  = args[:code]
    self.msg   = args[:msg]
    self.fatal = args[:fatal]
  end

  # Generic error messages.  (Also change docs at top of api_controller
  # and the permitted values in schema.xsd.)
  def title
    case code
    when 101 ; 'bad request method'
    when 102 ; 'bad request syntax'
    when 201 ; 'object not found'
    when 202 ; 'failed to create object'
    when 203 ; 'failed to update object'
    when 204 ; 'failed to delete object'
    when 301 ; 'authentication failed'
    when 302 ; 'permission denied'
    when 501 ; 'internal error'
    else       'unknown error'
    end
  end
end

