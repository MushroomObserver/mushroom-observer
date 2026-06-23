# frozen_string_literal: true

# Anchor linking to a model's `show` page with the model's title as
# the link text and a `<type>_link_<id>` CSS class for selector-based
# tests / JS hooks.
#
# Pass `button:` to add Bootstrap button styling alongside the
# identifier class (e.g. `button: :btn_link` emits `btn btn-link`).
# Omit `button:` for a plain unstyled link (the default).
class Components::Link::Object < Components::Link
  prop :object, _Nilable(::AbstractModel), default: nil
  prop :name, _Nilable(String), default: nil

  def view_template
    return unless @object

    a(href: url_for(@object.show_link_args),
      class: identifier_class) do
      trusted_html(@name || @object.title.t)
    end
  end

  private

  def identifier_class
    class_names(btn_styling, "#{@object.type_tag}_link_#{@object.id}")
  end
end
