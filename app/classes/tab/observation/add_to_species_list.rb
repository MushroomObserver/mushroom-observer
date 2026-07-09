# frozen_string_literal: true

# "Add to an Observation List" link — stands in as the Species
# Lists panel's whole heading when the observation doesn't belong
# to any species list yet. Caller must guard on
# `user&.species_list_ids&.any?` — same convention as
# `Tab::Observation::ManageLists`.
class Tab::Observation::AddToSpeciesList < Tab::Base
  def initialize(observation:, q_param: nil)
    super()
    @observation = observation
    @q_param = q_param
  end

  def title
    :show_observation_add_to_species_list.l
  end

  def path
    with_q_param(edit_observation_species_lists_path(@observation.id),
                 @q_param)
  end

  def html_options
    { icon: :add }
  end

  def model
    @observation
  end
end
