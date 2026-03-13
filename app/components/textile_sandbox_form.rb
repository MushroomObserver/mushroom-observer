# frozen_string_literal: true

# Form for testing Textile markup in a sandbox environment.
# Users can enter Textile code and see both the rendered output and HTML codes.
#
# @example Usage in view
#   render(Components::TextileSandboxForm.new(
#     textile_sandbox,
#     show_result: !code.nil?,
#     submit_type: submit
#   ))
class Components::TextileSandboxForm < Components::ApplicationForm
  # Register helpers
  register_value_helper :asset_path

  # @param model [FormObject::TextileSandbox] struct with code attribute
  # @param show_result [Boolean] whether to show the rendered result above form
  # @param submit_type [String] the submit button that was clicked
  def initialize(model, show_result: false, submit_type: nil, **)
    @show_result = show_result
    @submit_type = submit_type
    super(model, **)
  end

  def view_template
    render_result_section if @show_result

    super do
      render_up_arrows if @show_result
      render_code_field
      render_submit_buttons unless @show_result
    end

    render_help_section
  end

  private

  def form_action
    info_textile_sandbox_path
  end

  # Render the Textile input, showing either rendered HTML or HTML codes
  def render_result_section
    div(class: "mb-4") do
      strong { plain("#{:sandbox_look_like.l}:") }
      div(class: "sandbox mt-2") do
        if @submit_type == :sandbox_test.l
          # Render the textile code as HTML
          raw(@model.code.tpl) # rubocop:disable Rails/OutputSafety
        else
          # Show HTML codes as plain text
          code { plain(@model.code.tpl) }
        end
      end
    end
  end

  def render_up_arrows
    div(class: "sandbox-up-ptr center-block mt-3 mb-3") do
      img(src: asset_path("up_arrow.png"), alt: "Up arrow")
      whitespace
      submit(:sandbox_test.l, class: "btn btn-default")
      whitespace
      submit(:sandbox_test_codes.l, class: "btn btn-default")
      whitespace
      img(src: asset_path("up_arrow.png"), alt: "Up arrow")
    end
  end

  def render_code_field
    textarea_field(:code, label: "#{:sandbox_enter.l}:", rows: 8)
  end

  def render_submit_buttons
    submit(:sandbox_test.l, center: true)
  end

  def render_help_section
    render_quick_reference
    render_more_help_links
    render_web_reference_links
  end

  def render_quick_reference
    div(class: "mt-3") do
      p do
        strong { plain("#{:sandbox_quick_ref.l}:") }
      end
      pre { raw(:sandbox_sample.l) } # rubocop:disable Rails/OutputSafety
    end
  end

  def render_more_help_links
    strong { plain("#{:sandbox_more_help.l}:") }
    div(class: "pl-3") do
      # Translation not needed as document title is static
      a(href: "https://docs.google.com/document/d/" \
              "10NiaPDKoK_k3bRIoU1smGXSycDczf_jdkmW-xt-Wf20",
        target: "_blank",
        rel: "noopener noreferrer") { "MO Flavored Textile" }
      br
    end
  end

  def render_web_reference_links
    strong { plain("#{:sandbox_web_refs.l}:") }
    div(class: "pl-3") do
      a(href: "https://hobix.com/textile",
        target: "_blank",
        rel: "noopener noreferrer") do
        plain(:sandbox_link_hobix_textile_reference.l)
      end
      br
      a(href: "https://hobix.com/quick",
        target: "_blank",
        rel: "noopener noreferrer") do
        plain(:sandbox_link_hobix_textile_cheatsheet.l)
      end
      br
      a(href: "https://textile-lang.com/",
        target: "_blank",
        rel: "noopener noreferrer") do
        plain(:sandbox_link_textile_language_website.l)
      end
      br
    end
  end
end
