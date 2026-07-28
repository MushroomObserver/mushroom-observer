# frozen_string_literal: true

# The "When:" line for an observation. Owns its own `li.obs-when`
# wrapper (see Components::ObservationFragment::Who for why).
class Components::ObservationFragment::When < Components::Base
  prop :obs, ::Observation

  def view_template
    li(class: "obs-when hanging-indent") do
      plain("#{:when.ti}: ")
      b { @obs.when.web_date }
    end
  end
end
