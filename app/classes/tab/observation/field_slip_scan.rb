# frozen_string_literal: true

# "Scan photos" inline icon link beside the "Field Slip:" label on the
# observation show page -- the way to the observation-scoped scan page
# (every photo with its scan state, and the review of any read that
# already landed). Caller must guard on the scan page's own gate,
# `Observations::FieldSlipScansController#permission_required`: admin
# mode, or admin of a project the observation belongs to.
class Tab::Observation::FieldSlipScan < Tab::Base
  def initialize(observation:)
    super()
    @observation = observation
  end

  def title
    :field_slip_scan_tooltip.l
  end

  def alt_title
    "scan_observation_field_slip"
  end

  def path
    field_slip_scan_observation_path(@observation.id)
  end

  def html_options
    { icon: :qrcode }
  end

  def model
    @observation
  end
end
