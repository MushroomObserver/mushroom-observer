# frozen_string_literal: true

# "Edit naming" link. The naming's nested route requires the
# observation id as well as the naming id.
class Tab::Naming::Edit < Tab::Base
  def initialize(naming:)
    super()
    @naming = naming
  end

  def title
    :EDIT.l
  end

  def path
    edit_observation_naming_path(
      observation_id: @naming.observation_id, id: @naming.id
    )
  end

  def html_options
    { icon: :edit }
  end

  def model
    @naming
  end
end
