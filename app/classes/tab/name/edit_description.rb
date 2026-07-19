# frozen_string_literal: true

# Edit-description link for the name's primary description. Caller
# must guard on `name&.description && permission?(description)`
# before constructing (Tab POROs are request-agnostic; the helper
# delegator does this check).
class Tab::Name::EditDescription < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :edit.ti
  end

  def path
    edit_name_description_path(@name.description.id)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @name
  end
end
