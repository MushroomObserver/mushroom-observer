# frozen_string_literal: true

module Views
  module Controllers
    module Info
      # Phlex view template for the textile sandbox page.
      # Sets the page title and renders the form component.
      #
      # @example Usage in controller
      #   render(Views::Controllers::Info::TextileSandbox.new(
      #     textile_sandbox: textile_sandbox,
      #     show_result: !code.nil?,
      #     submit_type: submit
      #   ))
      class TextileSandbox < Views::Base
        # Register Rails helpers
        register_output_helper :help_block
        register_output_helper :add_page_title

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
          help_block(:div, :sandbox_header.tp)

          render(Components::TextileSandboxForm.new(
                   @textile_sandbox,
                   show_result: @show_result,
                   submit_type: @submit_type
                 ))
        end
      end
    end
  end
end
