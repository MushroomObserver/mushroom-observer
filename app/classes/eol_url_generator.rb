# encoding: utf-8
#
#  = EOL URL Generator
#
#    get_url
#
################################################################################

class EolUrlGenerator

  def url_generator.calc_url(object)
    if object.is_a?(Name)
      return "http://eol.org/search/#{name.text_name}"
    end
    # Throw an error?
  end
end
