# frozen_string_literal: true

# Action view for `observations/namings/votes#index`. That endpoint
# usually renders a Turbo modal (`Modal`, format.turbo_stream); this
# is its HTML fallback for direct/non-JS access -- a standalone
# vote-breakdown page for a single naming, with an in-body heading
# (not the page title bar) followed by the `Tally` rendering.
#
module Views::Controllers::Observations::Namings::Votes
  class Index < Views::FullPageBase
    # Reached by id via the route -- always a Naming, not a
    # MergedNaming. The modal-rendered Tally accepts both
    # (see its prop).
    prop :naming, ::Naming

    def view_template
      content_padding(:no_panels)
      h1(class: "h3") do
        trusted_html(:show_votes_title.t(
          name: viewer_aware_unique_format_name(@naming)
        ).small_author)
      end
      # Tally derives a consensus from `naming.observation` when
      # not explicitly passed, so the controller doesn't need to
      # hold one just for this render path.
      render(Tally.new(naming: @naming))
    end
  end
end
