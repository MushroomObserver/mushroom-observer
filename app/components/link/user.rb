# frozen_string_literal: true

# Anchor linking to a `User`'s show page with the user's login (or
# caller-supplied override) as the link text and a `user_link_<id>`
# CSS class for selector hooks. Falls back to a "User #<id>" label
# when only an Integer id is available, and renders the plain
# "Unknown User" string when `user` is nil.
#
# Pass `button:` to add Bootstrap button styling (e.g.
# `button: :link` renders `btn btn-link` alongside the identifier
# class).
class Components::Link::User < Components::Link::Object
  prop :user, _Nilable(_Union(::User, Integer)), default: nil
  # Pass-through HTML attributes — the caller-supplied `:class` is
  # merged with the identifier and any variant btn classes.
  prop :attributes, _Hash(_Union(Symbol, String), _Any?), default: -> { {} }

  def view_template
    if @user.nil?
      plain(:unknown_user_name.t)
      return
    end

    label, user_id = resolve_label_and_id
    a(href: url_for(user_path(user_id)), **link_attrs(user_id)) do
      plain(label)
    end
  end

  private

  def resolve_label_and_id
    if @user.is_a?(Integer)
      [@name || "#{:USER.t} ##{@user}", @user]
    else
      [@name || @user.unique_text_name, @user.id]
    end
  end

  def link_attrs(user_id)
    attrs = @attributes.dup
    validate_no_btn_classes!(attrs[:class])
    classes = class_names(btn_styling, "user_link_#{user_id}", attrs[:class])
    attrs.except(:class).merge(class: classes)
  end
end
