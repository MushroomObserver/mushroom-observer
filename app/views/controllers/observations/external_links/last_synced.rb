# frozen_string_literal: true

# "Last synced" line beside the occurrence-wide Sync button. Targeted by
# class, not id, because each loaded "Shared with" pane holds a copy;
# Inat::ObservationResyncer replaces every copy when a sync finishes.
module Views::Controllers::Observations::ExternalLinks
  class LastSynced < Views::Base
    prop :synced_at, _Nilable(Time)

    def view_template
      div(class: "reflection-last-synced text-muted small ml-2") do
        if @synced_at
          plain(append_colon(:observation_last_synced.l))
          span(data: { controller: "local-time",
                       local_time_utc_value: @synced_at.utc.iso8601 }) do
            @synced_at.display_time
          end
        else
          plain(:observation_never_synced.l)
        end
      end
    end
  end
end
