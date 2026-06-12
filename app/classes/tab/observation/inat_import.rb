# frozen_string_literal: true

# Link to the iNaturalist import flow. Lives in the Observation
# namespace because that's where it surfaces (observation index +
# new observation form action-nav).
class Tab::Observation::InatImport < Tab::Base
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  def title
    :create_observation_inat_import_link.l
  end

  def path
    with_q_param(new_inat_import_path, @q_param)
  end
end
