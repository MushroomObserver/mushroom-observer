# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Names::Show::ObservationsMenuTest < ComponentTestCase
  def setup
    super
    @name = names(:coprinus_comatus)
    @obss = Name::Observations.new(@name)
  end

  # `has_name_tracker: false` — `tracker_tab` returns NewTracker.
  # NewTracker#path → new_tracker_of_name_path → /names/:id/trackers/new
  def test_renders_new_tracker_link_when_no_tracker
    html = render_menu(has_name_tracker: false)

    assert_html(html, "#name_observations_menu")
    assert_html(html, "a[href*='/trackers/new']")
  end

  # `has_name_tracker: true` — `tracker_tab` returns EditTracker.
  # This branch is the missed line; it uses a different Tab subclass
  # than the `false` path above.
  # EditTracker#path → edit_tracker_of_name_path → /names/:id/trackers/edit
  def test_renders_edit_tracker_link_when_has_tracker
    html = render_menu(has_name_tracker: true)

    assert_html(html, "#name_observations_menu")
    assert_html(html, "a[href*='/trackers/edit']")
  end

  private

  def render_menu(has_name_tracker:, user: nil)
    render(Views::Controllers::Names::Show::ObservationsMenu.new(
             name: @name,
             obss: @obss,
             has_name_tracker: has_name_tracker,
             user: user
           ))
  end
end
