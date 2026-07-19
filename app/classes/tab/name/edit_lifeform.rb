# frozen_string_literal: true

class Tab::Name::EditLifeform < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :edit.ti
  end

  def path
    edit_lifeform_of_name_path(@name.id)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @name
  end
end
