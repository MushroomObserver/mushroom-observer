# frozen_string_literal: true

# Minimal padded-content wrapper: emits `<div class="p-3 ...">`
# around the block. Replaces the legacy `ContentHelper#content_padded`
# ERB helper for Phlex views.
#
# @example
#   render(Components::ContentPadded.new(id: "details")) do
#     p { plain("Field 1: ...") }
#   end
class Components::ContentPadded < Components::Base
  # @param id [String] optional `id=` for the wrapper div
  # @param class [String] CSS classes appended to the default "p-3"
  # @param attributes [Hash] arbitrary HTML attrs forwarded to the div
  def initialize(id: nil, class: nil, attributes: {})
    super()
    @html_id = id
    @html_class = binding.local_variable_get(:class)
    @attributes = attributes
  end

  def view_template(&block)
    div(class: class_names("p-3", @html_class), id: @html_id, **@attributes,
        &block)
  end
end
