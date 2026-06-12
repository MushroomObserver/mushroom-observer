# frozen_string_literal: true

# "Manage species lists for this observation" link. Caller must
# guard on `user&.species_list_ids&.any?` — the helper used to do
# this internally but Tab POROs are conditional-free.
class Tab::Observation::ManageLists < Tab::Base
  def initialize(observation:, q_param: nil)
    super()
    @observation = observation
    @q_param = q_param
  end

  def title
    :show_observation_manage_species_lists.l
  end

  def path
    with_q_param(edit_observation_species_lists_path(@observation.id),
                 @q_param)
  end

  def html_options
    { icon: :manage_lists }
  end

  def model
    @observation
  end
end
