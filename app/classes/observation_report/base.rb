# frozen_string_literal: true

module ObservationReport
  # base class
  class Base
    attr_accessor :encoding

    class_attribute :default_encoding
    class_attribute :mime_type
    class_attribute :extension
    class_attribute :header

    def initialize(args)
      self.encoding = args[:encoding] || default_encoding
      raise("ObservationReport initialized without encoding!") unless encoding
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
