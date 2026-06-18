# frozen_string_literal: true

module Views::Controllers::Info
  # Phlex view template for the textile sandbox page.
  # Sets the page title and renders the form component.
  #
  # @example Usage in controller
  #   render(Views::Controllers::Info::TextileSandbox.new(
  #     textile_sandbox: textile_sandbox,
  #     show_result: !code.nil?,
  #     submit_type: submit
  #   ))
  class TextileSandbox < Views::FullPageBase
    # Register Rails helpers

    # @param textile_sandbox [FormObject::TextileSandbox] the model
    # @param show_result [Boolean] whether to show rendered result
    # @param submit_type [String] the submit button clicked
    def initialize(textile_sandbox:, show_result:, submit_type:)
      super()
      @textile_sandbox = textile_sandbox
      @show_result = show_result
      @submit_type = submit_type
    end

    def view_template
      add_page_title(:sandbox_title.t)
      render(Components::Help::Block.new(:div, :sandbox_header.tp))

      render(Views::Controllers::Info::TextileSandboxForm.new(
               @textile_sandbox,
               show_result: @show_result,
               submit_type: @submit_type
             ))
    end
  end
end
