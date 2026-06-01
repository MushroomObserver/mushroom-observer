# frozen_string_literal: true

class Tab::Name::EditClassification < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :EDIT.l
  end

  def path
    edit_classification_of_name_path(@name.id)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @name
  end
end
