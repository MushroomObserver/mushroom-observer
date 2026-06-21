# frozen_string_literal: true

# "Move this description to a different parent" icon-link (admin
# only). Caller is responsible for the admin permission check
# before instantiating.
class Tab::Description::Move < Tab::Base
  def initialize(description:)
    super()
    @description = description
    @type = description.parent.type_tag
  end

  def title
    :show_description_move.t
  end

  def path
    send(:"new_move_#{@type}_description_path", @description.id)
  end

  def html_options
    { help: :show_description_move_help.l(parent: @type.to_s), icon: :move }
  end

  def model
    @description
  end
end
