# frozen_string_literal: true

# "Deprecate" link — appears on approved names, with the "approved"
# icon (a check) to signal at-a-glance that this name is approved
# and the action will deprecate it.
class Tab::Name::Deprecate < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :DEPRECATE.l
  end

  def path
    form_to_deprecate_synonym_of_name_path(@name.id)
  end

  def html_options
    { icon: :deprecate }
  end

  def model
    @name
  end
end
