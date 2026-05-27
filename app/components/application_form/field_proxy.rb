# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Lightweight field proxy for use outside of a form rendering context.
  # Provides the same interface as Superform::Field for field components.
  # Unlike Superform fields, these can be created and rendered many times.
  #
  # @example Hand-built (still works; equivalent to the helper below)
  #   proxy = FieldProxy.new("observation[good_image][123]", :notes, "text")
  #   render(TextField.new(proxy, wrapper_options: {}))
  #
  # @example Via the form's field helpers with a String `field_name`
  #   text_field("observation[good_image][123][notes]", value: "text")
  #   # Internally: FieldProxy.new(nil, "observation[...]", "text").text(...)
  #
  # Mirrors `Field`'s factory-method surface (`text`, `textarea`,
  # `checkbox`, `radio`, `select`, `autocompleter`, `date`, `file`,
  # `read_only`, `static`) so the form's `*_field` helpers can dispatch
  # Symbol → `field(name)` (model-bound) and String → `FieldProxy.new(...)`
  # (raw `name=` attribute) through one code path. Same precedent
  # `hidden_field` has established; this generalizes it.
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

    include FieldFactoryMethods

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
        # When `field_key` is a String containing the full raw `name=`
        # attribute (with `[...]` segments), we still need to normalize
        # it to a valid HTML id — otherwise a name like
        # `"reviewed[385495444]"` would produce an `id` with literal
        # brackets, and Capybara / `getElementById` lookups would fail.
        # Applies the same `[]`→`_` normalization the namespaced case
        # uses, then strips trailing `_` (from a trailing `]`).
        raw = if @namespace.blank?
                @field_key.to_s
              else
                "#{@namespace}_#{@field_key}"
              end
        raw.tr("[]", "_").gsub(/__+/, "_").chomp("_")
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
