# frozen_string_literal: true

# "Create herbarium record for this observation" link.
class Tab::HerbariumRecord::New < Tab::Base
  def initialize(observation:)
    super()
    @observation = observation
  end

  def title
    :create_herbarium_record.l
  end

  def path
    new_herbarium_record_path(observation_id: @observation.id)
  end

  def html_options
    { icon: :add }
  end

  def model
    Herbarium
  end
end
