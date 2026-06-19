# frozen_string_literal: true

# Action view for `observations/namings#index` — the standalone
# namings table rendered into the obs-show page (and used as a
# turbo_stream target for naming-related updates).
#
# Wraps `Show::Namings` in a `#observation_namings` div so the
# controller's mutation broadcasts can `turbo_stream.replace` it.
#
module Views::Controllers::Observations::Namings
  class Index < Views::FullPageBase
    prop :observation, ::Observation
    prop :user, _Nilable(::User), default: nil

    def view_template
      # Consensus is a pure derivation of the observation —
      # computing it here keeps the controller free of an ivar
      # whose only job is to be passed through.
      consensus = ::Observation::NamingConsensus.new(@observation)
      div(id: "observation_namings") do
        render(::Views::Controllers::Observations::Show::Namings.new(
                 obs: @observation, user: @user, consensus: consensus
               ))
      end
    end
  end
end
