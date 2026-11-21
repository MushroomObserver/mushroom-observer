# frozen_string_literal: true

# How many of a project's targets have a saved iNat lookup, while
# InatTargetLookupJob works through the rest. The job replaces it as
# it goes.
module Views::Controllers::Projects::ExternalSites
  class LookupProgress < Views::Base
    prop :looked_up, Integer
    prop :total, Integer

    def view_template
      p(class: "mt-2", id: "inat_target_lookup_progress") do
        :project_sites_lookups_incomplete.t(looked_up: @looked_up,
                                            total: @total)
      end
    end
  end
end
