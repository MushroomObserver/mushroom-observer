# frozen_string_literal: true

class Tab::Name::NewDescription < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_name_create_description.l
  end

  def path
    new_name_description_path(@name.id)
  end

  def html_options
    { icon: :add }
  end

  def model
    @name
  end
end
