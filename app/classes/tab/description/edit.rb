# frozen_string_literal: true

# "Edit this description" icon-link. Caller is responsible for the
# `user_writer?(user, description)` permission check before
# instantiating.
class Tab::Description::Edit < Tab::Base
  def initialize(description:)
    super()
    @description = description
    @type = description.parent.type_tag
  end

  def title
    :show_description_edit.t
  end

  def path
    send(:"edit_#{@type}_description_path", @description.id)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @description
  end
end
