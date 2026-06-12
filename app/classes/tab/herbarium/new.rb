# frozen_string_literal: true

class Tab::Herbarium::New < Tab::Base
  def title
    :create_herbarium.l
  end

  def path
    new_herbarium_path
  end

  def alt_title
    "new_herbarium"
  end

  def model
    Herbarium
  end
end
