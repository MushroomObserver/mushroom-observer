module DatabaseHelper
  def xml_date(x); !x ? nil : x.strftime('%Y-%m-%d');          end
  def xml_time(x); !x ? nil : x.strftime('%Y-%m-%d %H:%M:%S'); end

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

  def title
    case code
    when 101 ; 'bad request type'
    when 102 ; 'bad request syntax'
    when 201 ; 'object not found'
    when 301 ; 'authentication failed'
    when 501 ; 'internal error'
    else       'unknown error'
    end
  end
end

