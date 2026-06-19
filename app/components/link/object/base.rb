# frozen_string_literal: true

# Anchor linking to a model's `show` page with the model's title as
# the link text and a `<type>_link_<id>` CSS class for selector-based
# tests / JS hooks.
#
# Callers pass the AR object and, optionally, an override link text
# (defaults to the object's textilized `#title`).
class Components::Link::Object::Base < Components::Base
  prop :object, _Nilable(::AbstractModel), default: nil
  prop :name, _Nilable(String), default: nil

  def view_template
    return unless @object

    a(href: url_for(@object.show_link_args),
      class: "#{@object.type_tag}_link_#{@object.id}") do
      trusted_html(@name || @object.title.t)
    end
  end
end
