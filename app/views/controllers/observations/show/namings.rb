# frozen_string_literal: true

# Outer composition of the obs-show namings sub-panel.
#
# Wraps the four sub-views (`Header`, `Rows`, `FooterButtons`,
# `FooterLegend`) in a `Components::Panel` rooted under the
# `section-update` Stimulus controller. Action Cable broadcasts
# from `NamingsController` / `VotesController` write into the
# rows-container id (`namings_table_rows`, set by `Rows`); the
# `section-update` controller listens for those broadcasts and
# closes any open in-flight modal so the user sees the result
# of their action immediately.
#
# Replaces `app/views/controllers/observations/show/_namings.erb`.
class Views::Controllers::Observations::Show::Namings < Views::Base
  prop :obs, ::Observation
  prop :user, ::User
  prop :consensus, ::Observation::NamingConsensus

  def view_template
    render(::Components::Panel.new(
             panel_id: "observation_namings",
             panel_class: "namings-table mb-4",
             attributes: { data: panel_data }
           )) do |panel|
      register_panel_slots(panel)
    end
  end

  private

  def panel_data
    {
      controller: "section-update",
      section_update_user_value: @user.id
    }
  end

  def register_panel_slots(panel)
    panel.with_heading(title: false, classes: "namings-table-header") do
      render(Header.new(obs: @obs))
    end
    panel.with_body(wrapper: false) do
      render(Rows.new(user: @user, consensus: @consensus))
    end
    panel.with_footer do
      render(FooterButtons.new(user: @user, obs: @obs))
    end
    # Legend hidden on `xs` — on mobile only the rows + the propose
    # button matter; the eye icons aren't shown either since the
    # eyes-column is `d-none d-sm-block` in the row body.
    panel.with_footer(classes: "d-none d-sm-block py-2") do
      render(FooterLegend.new)
    end
  end
end
