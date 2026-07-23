# frozen_string_literal: true

# "Add external link to this observation" link.
class Tab::ExternalLink::New < Tab::Base
  def initialize(observation:)
    super()
    @observation = observation
  end

  def title
    :add_object.t(type: :external_link)
  end

  def path
    new_external_link_path(id: @observation.id)
  end
end
