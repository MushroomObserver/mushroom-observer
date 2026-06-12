# frozen_string_literal: true

# Anchor linking to a `User`'s show page with the user's
# `unique_text_name` (or caller-supplied override) as the link text
# and a `user_link_<id>` CSS class for selector hooks. Falls back to
# a "User #<id>" label when only an Integer id is available, and
# renders the plain "Unknown User" string when `user` is nil.
#
# Replaces the `user_link` helper from `app/helpers/object_link_helper.rb`.
class Components::UserLink < Components::Base
  prop :user, _Nilable(_Union(::User, Integer)), default: nil
  prop :name, _Nilable(String), default: nil
  # Pass-through HTML attributes — the caller-supplied `:class` is
  # merged with the `user_link_<id>` identifier class.
  prop :attributes, _Hash(_Union(Symbol, String), _Any?),
       default: -> { {} }

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
    classes = class_names("user_link_#{user_id}", attrs[:class])
    attrs.except(:class).merge(class: classes)
  end
end
