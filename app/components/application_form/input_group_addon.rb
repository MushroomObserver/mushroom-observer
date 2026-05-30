# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared input-group decoration for TextField + SelectField. The
  # field renders inside `<div class="input-group">` and a trailing
  # `<span class="input-group-btn">` holds either a `<button>` or an
  # `<a>` styled as a button — caller picks via `:button_href` (link
  # if present, button otherwise).
  #
  # Wrapper options consumed:
  #   :button          text content for the addon (String)
  #   :button_href     anchor URL — switches the addon to `<a>`
  #   :button_class    overrides the default `btn btn-default`
  #   :button_data     Hash of `data-*` attributes
  #   :button_target   `target=` attribute (e.g. `_blank`)
  #   :button_rel      `rel=`    attribute (e.g. `noopener noreferrer`)
  #   :button_title    tooltip / accessible name
  #   :button_icon     glyph symbol from `LINK_ICON_INDEX`, rendered
  #                    after the text via the `link_icon` helper
  module InputGroupAddon
    def render_input_group_button(&block)
      div(class: "input-group") do
        yield
        span(class: "input-group-btn") { render_addon_element }
      end
    end

    def render_input_group_addon(&block)
      div(class: "input-group") do
        yield
        span(class: "input-group-addon") { wrapper_options[:addon] }
      end
    end

    private

    def render_addon_element
      if wrapper_options[:button_href]
        a(href: wrapper_options[:button_href], **addon_attributes) do
          render_addon_label
        end
      else
        button(type: "button", **addon_attributes) { render_addon_label }
      end
    end

    def addon_attributes
      attrs = {
        class: wrapper_options[:button_class] || "btn btn-default",
        data: wrapper_options[:button_data] || {}
      }
      [:target, :rel, :title].each do |key|
        val = wrapper_options[:"button_#{key}"]
        attrs[key] = val if val
      end
      attrs
    end

    # Renders the addon's visible label: the `:button` text + an
    # optional `:button_icon` (rendered after a space via the
    # `link_icon` helper — same one used everywhere else).
    def render_addon_label
      plain(wrapper_options[:button])
      return unless wrapper_options[:button_icon]

      whitespace
      trusted_html(link_icon(wrapper_options[:button_icon]))
    end
  end
end
