# frozen_string_literal: true

# What the saved configuration would bring in, below both source shapes
# -- the number answers to the two together, and follows what is stored
# rather than what is on screen, which is why it names the button that
# would refresh it.
#
# A separate view so InatTargetLookupJob can replace it on the page once
# every target is looked up.
module Views::Controllers::Projects::ExternalSites
  class Candidates < Views::Base
    prop :candidates, ::Inat::CandidateCount::Candidates
    prop :import_limit, Integer

    def view_template
      div(id: "project_site_candidates") do
        text = candidates_text
        p(class: "mt-2") { text } if text
        render_over_limit
        render_progress
        render_unresolved(:project_sites_unresolved_names,
                          @candidates.unresolved_names)
        render_unresolved(:project_sites_unresolved_locations,
                          @candidates.unresolved_locations)
      end
    end

    private

    def candidates_text
      return :project_sites_unbounded.t unless @candidates.configured
      return nil unless @candidates.total

      :project_sites_candidates.t(count: @candidates.total)
    end

    def render_over_limit
      return unless @candidates.total.to_i > @import_limit

      p(class: "mt-2") do
        :project_sites_over_limit.t(limit: @import_limit)
      end
    end

    def render_progress
      return unless @candidates.incomplete?

      render(LookupProgress.new(looked_up: @candidates.looked_up,
                                total: @candidates.targets))
    end

    # A target iNat does not know is left out of the search rather than
    # guessed at, which is worth saying: it is why a count can be larger
    # than the project means.
    def render_unresolved(tag, targets)
      return if targets.blank?

      p(class: "mt-2") { tag.t(targets: targets.join(", ")) }
    end
  end
end
