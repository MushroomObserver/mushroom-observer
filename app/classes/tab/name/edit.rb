# frozen_string_literal: true

class Tab::Name::Edit < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_name_edit_name.l
  end

  def path
    edit_name_path(@name.id)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @name
  end
end
