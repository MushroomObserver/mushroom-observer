# frozen_string_literal: true

# "Attach to Field Slip" inline icon link — shown next to the
# "Field Slip:" label on the observation show page's Details panel
# when the observation has none yet. Caller must guard on
# `in_admin_mode? || obs.can_edit?(user)` — matches the permission
# gate `Observations::FieldSlipsController` itself enforces.
class Tab::Observation::AttachFieldSlip < Tab::Base
  def initialize(observation:)
    super()
    @observation = observation
  end

  def title
    :field_slip_attach_tooltip.l
  end

  # "Attach" alone would derive a generic attach_observation_link
  # selector class -- too easily confused with other "attach
  # observation to X" tabs.
  def alt_title
    "attach_observation_to_field_slip"
  end

  def path
    edit_observation_field_slip_path(@observation.id)
  end

  def html_options
    { icon: :add }
  end

  def model
    @observation
  end
end
