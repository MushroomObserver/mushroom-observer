# frozen_string_literal: true

# Page component for the Textile Sandbox.
# Wraps the form with the page title and help block.
#
# @example Usage in controller
#   render(Components::TextileSandbox.new(
#     textile_sandbox,
#     show_result: !code.nil?,
#     submit_type: submit
#   ), layout: true)
class Components::TextileSandbox < Components::Base
  register_output_helper :help_block
  register_output_helper :add_page_title

  # @param model [TextileSandbox] the textile sandbox model
  # @param show_result [Boolean] whether to show the rendered result
  # @param submit_type [String] the submit button that was clicked
  def initialize(model, show_result: false, submit_type: nil)
    super()
    @model = model
    @show_result = show_result
    @submit_type = submit_type
  end

  def view_template
    add_page_title(:sandbox_title.t)

    help_block(:div, :sandbox_header.tp)

    render(Components::TextileSandboxForm.new(
             @model,
             show_result: @show_result,
             submit_type: @submit_type
           ))
  end
end
