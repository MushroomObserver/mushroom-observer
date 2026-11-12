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
  #   :addon           text content for a plain (non-button) addon
  #   :addon_position  :prepend or :append (default) -- BS3's addon
  #                    span carries no prepend/append class of its
  #                    own, so position is just DOM order here
  module InputGroupAddon
    # One `.input-group` for a `:button`/`:addon` decoration plus the
    # autocompleter's append-slot dropdown (FieldWrapperRendering's
    # `wrap_append_in_input_group`) -- two separate `InputGroup` wraps
    # here would nest, and this app's flex-based `.input-group`
    # (`_links_buttons_alerts.scss`) won't stretch a nested one to
    # fill the row. TODO(bs4-cutover): re-check against that branch's
    # `.input-group-append`/`-prepend` markup.
    def render_input_group(&block)
      position = wrapper_options.fetch(:addon_position, :append)
      InputGroup do
        render_addon if addon_present? && !wrapper_options[:button] &&
                        position == :prepend
        yield
        # append_slot (e.g. the autocompleter's dropdown-menu) renders
        # before the trailing addon/button, not after: it's an
        # absolutely-positioned overlay, so DOM order doesn't affect
        # its placement, but Bootstrap's border-radius-flattening CSS
        # keys off `:last-child` -- the addon/button has to stay the
        # literal last child for its outer corner to flatten.
        render(append_slot) if append_present?
        render_input_group_trailing(position)
      end
    end

    private

    def render_input_group_trailing(position)
      if wrapper_options[:button]
        render(Components::InputGroup::Addon.new) { render_addon_element }
      elsif position == :append && addon_present?
        render_addon
      end
    end

    def addon_present?
      wrapper_options[:addon].present?
    end

    def render_addon
      render(Components::InputGroup::Addon.new(variant: :addon)) do
        wrapper_options[:addon]
      end
    end

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
      span { plain(wrapper_options[:button]) }
      return unless wrapper_options[:button_icon]

      span(class: "icon-text-gap")
      Icon(type: wrapper_options[:button_icon])
    end
  end
end
