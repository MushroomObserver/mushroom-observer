# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Lightweight field proxy for use outside of a form rendering context.
  # Provides the same interface as Superform::Field for field components.
  # Unlike Superform fields, these can be created and rendered many times.
  #
  # @example
  #   proxy = FieldProxy.new("observation[good_image][123]", :notes, "text")
  #   render(TextField.new(proxy, wrapper_options: {}))
  class FieldProxy
    attr_reader :key, :value, :dom

    def initialize(namespace, field_key, field_value = nil)
      @key = field_key
      @value = field_value
      @dom = DOMProxy.new(namespace, field_key, field_value)
    end

    # FieldProxy stands in for a Superform::Field outside a form
    # context, where the field has no parent. Superform's
    # `Checkbox#collection?` checks `field.parent.is_a?(Superform::Field)`
    # to decide whether to render array-mode markup; returning nil here
    # routes to the boolean branch, which is what FieldProxy-backed
    # standalone checkboxes want.
    def parent
      nil
    end

    # Factory method to create a FieldProxy for image fields.
    # @param type [Symbol] :good_image or :image
    # @param image_id [Integer, String] the image ID
    # @param field_key [Symbol] the field name (:notes, :when, etc.)
    # @param value [Object] the field value
    # @return [FieldProxy] a field proxy for use with field components
    def self.image_proxy(type, image_id, field_key, value = nil)
      namespace = "observation[#{type}][#{image_id}]"
      new(namespace, field_key, value)
    end

    # Minimal DOM proxy that provides id, name, value for field components
    class DOMProxy
      def initialize(namespace, field_key, field_value)
        @namespace = namespace
        @field_key = field_key
        @field_value = field_value
      end

      def id
        return @field_key.to_s if @namespace.blank?

        "#{@namespace}_#{@field_key}".tr("[]", "_").gsub(/__+/, "_")
      end

      def name
        return @field_key.to_s if @namespace.blank?

        "#{@namespace}[#{@field_key}]"
      end

      def value
        @field_value.to_s
      end
    end
  end
end
