# frozen_string_literal: true

class API2
  # API exception base class for errors having to do with database records.
  class ObjectError < FatalError
    def initialize(obj)
      super()
      args.merge!(type: obj.type_tag, name: display_name(obj))
    end

    def display_name(obj)
      if obj.respond_to?(:unique_text_name)
        obj.unique_text_name
      elsif obj.respond_to?(:display_name)
        obj.display_name
      elsif obj.respond_to?(:name)
        obj.name
      elsif obj.respond_to?(:title)
        obj.title
      else
        "##{obj.id}"
      end
    end
  end
end
