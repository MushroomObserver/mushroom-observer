# frozen_string_literal: true

# "Approve" link — appears on deprecated names. Icon is the
# "deprecated" exclamation to signal at-a-glance that this name is
# currently deprecated and the action will approve it.
class Tab::Name::Approve < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :approve.ti
  end

  def path
    form_to_approve_synonym_of_name_path(@name.id)
  end

  def html_options
    { icon: :approve }
  end

  def model
    @name
  end
end
