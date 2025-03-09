# frozen_string_literal: true

# Overrides because we want these logged at info, not debug level
module CoreExtensions
  module ActionView
    module LogSubscriber
      def render_collection(event)
        identifier = event.payload[:identifier] || "templates"

        info do
          message = +"  Rendered collection of #{from_rails_root(identifier)}"
          if event.payload[:layout]
            message << " within #{from_rails_root(event.payload[:layout])}"
          end
          message << " #{render_count(event.payload)} " \
            "(Duration: #{event.duration.round(1)}ms | " \
            "Allocations: #{event.allocations})"
        end
      end

      def render_partial(event)
        if event.payload[:cache_hit].present?
          info do
            message = +"  Rendered " \
              "#{from_rails_root(event.payload[:identifier])}"
            if event.payload[:layout]
              message << " within #{from_rails_root(event.payload[:layout])}"
            end
            message << " (Duration: #{event.duration.round(1)}ms | " \
              "Allocations: #{event.allocations})"
            return message if event.payload[:cache_hit].nil?

            message << " #{cache_message(event.payload)}"
          end
        else
          debug do
            message = +"  Rendered " \
              "#{from_rails_root(event.payload[:identifier])}"
            if event.payload[:layout]
              message << " within #{from_rails_root(event.payload[:layout])}"
            end
            message << " (Duration: #{event.duration.round(1)}ms | " \
              "Allocations: #{event.allocations})"
          end
        end
      end
      # ::ActionView::LogSubscriber.subscribe_log_level :render_partial, :info
    end
  end
end
