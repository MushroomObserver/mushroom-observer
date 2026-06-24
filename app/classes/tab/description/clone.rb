# frozen_string_literal: true

# "Clone this description" icon-link. Sends the user to the
# new-description form with `?clone=<id>` so the form is
# pre-populated from this description.
class Tab::Description::Clone < Tab::Base
  def initialize(description:)
    super()
    @description = description
    @type = description.parent.type_tag
  end

  def title
    :show_description_clone.t
  end

  def path
    send(:"new_#{@type}_description_path",
         { clone: @description.id,
           "#{@type}_id": @description.parent_id })
  end

  def html_options
    { confirm: :show_description_clone_help.l, icon: :clone }
  end

  def model
    @description
  end
end
