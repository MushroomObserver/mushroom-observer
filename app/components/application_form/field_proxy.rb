# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Lightweight field proxy for use outside of form rendering context.
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
