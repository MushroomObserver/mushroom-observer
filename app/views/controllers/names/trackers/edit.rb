# frozen_string_literal: true

# Action template for `Names::TrackersController#edit`. Renders
# page-chrome + a rank-aware help blurb + the
# `Names::Trackers::Form` Phlex form on the existing tracker.
class Views::Controllers::Names::Trackers::Edit < Views::Base
  prop :name, ::Name
  prop :name_tracker, ::NameTracker
  prop :note_template, _Nilable(String), default: nil

  def view_template
    add_page_title(:email_tracking_title.t(name: @name.display_name))
    add_context_nav(Tab::Name::FormsReturn.new(name: @name))

    div(class: "mt-5 mb-5") { trusted_html(help_blurb) }

    render(Views::Controllers::Names::Trackers::Form.new(
             @name_tracker, note_template: @note_template
           ))
  end

  private

  def help_blurb
    if @name.at_or_below_species?
      :email_tracking_help_below_species.tp(
        name: @name.display_name_without_authors
      )
    else
      :email_tracking_help_above_species.tp(
        rank: @name.rank_translated
      )
    end
  end
end
