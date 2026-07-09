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
  #   :button_icon     glyph symbol from `Components::Icon::GLYPHS`,
  #                    rendered after the text via `Components::Icon`
  module InputGroupAddon
    def render_input_group_button(&block)
      InputGroup do
        yield
        render(Components::InputGroup::Addon.new) { render_addon_element }
      end
    end

    def render_input_group_addon(&block)
      InputGroup do
        yield
        render(Components::InputGroup::Addon.new(variant: :addon)) do
          wrapper_options[:addon]
        end
      end
    end

    private

    def render_addon_element
      if wrapper_options[:button_href]
        Button(tag: :a, href: wrapper_options[:button_href],
               **addon_button_kwargs) { render_addon_label }
      else
        Button(**addon_button_kwargs) { render_addon_label }
      end
    end

    def addon_button_kwargs
      kwargs = {
        variant: wrapper_options[:button_variant],
        size: wrapper_options[:button_size],
        data: wrapper_options[:button_data] || {}
      }
      [:target, :rel, :title].each do |key|
        val = wrapper_options[:"button_#{key}"]
        kwargs[key] = val if val
      end
      kwargs
    end

    # Renders the addon's visible label: the `:button` text + an
    # optional `:button_icon` (rendered after a space via the
    # `Components::Icon` component).
    def render_addon_label
      plain(wrapper_options[:button])
      return unless wrapper_options[:button_icon]

      whitespace
      Icon(type: wrapper_options[:button_icon])
    end
  end
end
