# frozen_string_literal: true

class Tab::Name::EditSynonym < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_name_change_synonyms.l
  end

  def path
    edit_synonyms_of_name_path(@name.id)
  end

  def html_options
    { icon: :synonyms }
  end

  def model
    @name
  end
end
