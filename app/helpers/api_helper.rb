#
#  = API Helpers
#
#  Methods available to API XML responses:
#
#  xml_date::            Render date/time as "YYYY-MM-DD".
#  xml_time::            Render date/time as "HH:MM:SS".
#  xml_datetime::        Render date/time as "YYYY-MM-DD HH:MM:SS".
#  ---
#  render_xml_partial::  Render partial as embedded XML.
#
################################################################################

module ApiHelper
  def xml_date(x);     !x ? nil : x.strftime('%Y-%m-%d');          end
  def xml_time(x);     !x ? nil : x.strftime('%H:%M:%S');          end
  def xml_datetime(x); !x ? nil : x.strftime('%Y-%m-%d %H:%M:%S'); end

  # Convenience macro.  The following two are equivalent:
  #
  #   render_xml_partial(xml, 'partial', :key => val, ...)
  #   xml.target! << render(:partial => 'partial', :key => val, ...)
  #
  def render_xml_partial(xml, partial, args={})
    args[:partial] = partial.to_s
    xml.target! << render(args)
  end
end
