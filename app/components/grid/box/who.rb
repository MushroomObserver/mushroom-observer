# frozen_string_literal: true

# Who a grid box names for an Observation: the collector, falling
# back to the entering user when none is recorded. The one-line box
# drops the "Entered by:" line `ObservationFragment::Who` adds.
class Components::Grid::Box::Who < Components::Base
  prop :obs, ::Observation

  def view_template
    span(class: "log-who") do
      if @obs.collector_user
        Link(type: :user, user: @obs.collector_user)
      elsif (login = @obs.inat_collector_login)
        Link(type: :external, content: login,
             path: "#{Inat::Constants::SITE}/people/#{login}")
      elsif @obs.collector.present?
        plain(@obs.collector)
      else
        Link(type: :user, user: @obs.user)
      end
    end
  end
end
