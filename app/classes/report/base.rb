# frozen_string_literal: true

module Report
  # base class
  class Base
    attr_accessor :encoding

    # These used to be class attributes, now are just regular instance methods:
    #  default_encoding
    #  mime_type
    #  extension
    #  header

    def initialize(args)
      self.encoding = args[:encoding] || default_encoding
      raise("Report initialized without encoding!") unless encoding
    end

    def filename
      "observations_#{query.id&.alphabetize}.#{extension}"
    end

    def body
      case encoding
      when "UTF-8"
        render
      when "ASCII"
        render.to_ascii
      else
        render.iconv(encoding) # This caused problems with UTF-16 encoding.
      end
    end
  end
end
