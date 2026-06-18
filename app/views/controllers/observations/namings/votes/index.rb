# frozen_string_literal: true

# Action view for `observations/namings/votes#index` — the
# standalone vote-breakdown page for a single naming. Body is
# just the `Table` rendering; the page title carries the
# naming's display name.
#
# Replaces `app/views/controllers/observations/namings/votes/index.erb`.
module Views::Controllers::Observations::Namings::Votes
  class Index < Views::FullPageBase
    # HTML index renders against a raw `Naming` because the page
    # title reads `unique_format_name`. The modal-rendered Table
    # accepts MergedNaming too (see Table's prop).
    prop :naming, ::Naming

    def view_template
      add_page_title(:show_votes_title.t(
                       name: @naming.unique_format_name
                     ))
      # Table derives its own consensus from `naming.observation`
      # when not explicitly passed, so the controller doesn't need
      # to hold one just for this render path.
      render(Table.new(naming: @naming))
    end
  end
end
