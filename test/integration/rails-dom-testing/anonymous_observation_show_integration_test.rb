# frozen_string_literal: true

require("test_helper")

# `/obs/<id>` is the one observation address open to a visitor with no
# account, and `not_logged_in_show_includes` is what it eager-loads.
# Anything the page reads outside that scope lazy-loads -- logged in
# production, raised here -- so these walk a spread of fixtures to keep
# the scope and the page in step.
class AnonymousObservationShowIntegrationTest < IntegrationTestCase
  # One per shape the show page renders: external links, an occurrence,
  # a deprecated consensus whose synonyms get counted, images, comments,
  # sequences, fungarium records, projects and species lists.
  FIXTURES = [
    :minimal_unknown_obs, :detailed_unknown_obs, :coprinus_comatus_obs,
    :agaricus_campestris_obs, :deprecated_name_obs,
    :all_namings_deprecated_obs, :two_img_obs, :vouchered_imged_obs,
    :locally_sequenced_obs, :genbanked_obs, :unknown_with_lat_lng,
    :trusted_hidden, :amateur_obs, :peltigera_obs, :substrate_notes_obs,
    :template_and_other_notes_obs
  ].freeze

  def test_anonymous_show_page_loads_nothing_lazily
    sweep_the_fixtures
  end

  # The same sweep against `show_includes_tree`, the scope behind the
  # page a member sees. The per-synonym counts were an N+1 here too.
  def test_logged_in_show_page_loads_nothing_lazily
    login

    sweep_the_fixtures
  end

  private

  def sweep_the_fixtures
    FIXTURES.each do |fixture|
      get("/obs/#{observations(fixture).id}")

      assert_response(:success, "#{fixture} failed")
    end
  end
end
