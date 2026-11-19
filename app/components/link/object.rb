# frozen_string_literal: true

# Anchor linking to a model's `show` page with the model's title as
# the link text and a `<type>_link_<id>` CSS class for selector-based
# tests / JS hooks.
#
# Pass `button:` to add Bootstrap button styling alongside the
# identifier class (e.g. `button: :link` emits `btn btn-link`).
# Omit `button:` for a plain unstyled link (the default).
class Components::Link::Object < Components::Link
  prop :object, _Nilable(::AbstractModel), default: nil
  prop :name, _Nilable(String), default: nil
  # Pass-through HTML attributes -- the caller-supplied `:class` is
  # merged with the identifier and any variant btn classes.
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template(&block)
    return unless @object

    a(href: url_for(@object.show_link_args), **link_attrs) do
      block ? yield : trusted_html(@name || @object.title.t)
    end
  end

  private

  def link_attrs
    @attributes.except(:class).merge(class: identifier_class)
  end

  def identifier_class
    class_names(btn_styling, "#{@object.type_tag}_link_#{@object.id}",
                @attributes[:class])
  end
end
