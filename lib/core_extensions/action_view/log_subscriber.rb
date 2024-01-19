# frozen_string_literal: true

# Overrides because we want these logged at info, not debug level
module CoreExtensions
  module ActionView
    module LogSubscriber
      def render_collection(event)
        identifier = event.payload[:identifier] || "templates"

        info do
          message = +"  Rendered collection of #{from_rails_root(identifier)}"
          message << " within #{from_rails_root(event.payload[:layout])}" if event.payload[:layout]
          message << " #{render_count(event.payload)} (Duration: #{event.duration.round(1)}ms | Allocations: #{event.allocations})"
          message
        end
      end
      # ::ActionView::LogSubscriber.subscribe_log_level :render_collection, :info

      def render_partial(event)
        if event.payload[:cache_hit].present?
          info do
            message = +"  Rendered #{from_rails_root(event.payload[:identifier])}"
            message << " within #{from_rails_root(event.payload[:layout])}" if event.payload[:layout]
            message << " (Duration: #{event.duration.round(1)}ms | Allocations: #{event.allocations})"
            message << " #{cache_message(event.payload)}" unless event.payload[:cache_hit].nil?
            message
          end
        else
          debug do
            message = +"  Rendered #{from_rails_root(event.payload[:identifier])}"
            message << " within #{from_rails_root(event.payload[:layout])}" if event.payload[:layout]
            message << " (Duration: #{event.duration.round(1)}ms | Allocations: #{event.allocations})"
            message
          end
        end
      end
      # ::ActionView::LogSubscriber.subscribe_log_level :render_partial, :info
    end
  end
end
