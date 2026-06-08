# frozen_string_literal: true

require("test_helper")

# Contract tests for the 4 classification-action Tabs that live on
# the Names::Show classification panel:
#
#   - `Tab::Name::Subtaxa`               (link to filtered Names index)
#   - `Tab::Name::RefreshClassification` (PUT button, visibility-gated)
#   - `Tab::Name::PropagateClassification` (PUT button, visibility-gated)
#   - `Tab::Name::InheritClassification` (link, visibility-gated)
#
# The visibility predicates use `.for(name:)` / `.visible_for?(name:)`.
# Path construction (`controller.add_q_param`) is exercised by the
# names-show controller test.
class Tab::Name::ClassificationLinkTabsTest < UnitTestCase
  def setup
    @genus = names(:coprinus)
    @species = names(:coprinus_comatus)
  end

  # --- Tab::Name::Subtaxa ---------------------------------------

  def test_subtaxa_title_uses_show_object_with_type
    # `at_or_below_genus? && !at_or_below_species?` → "Species"
    # branch.
    tab = Tab::Name::Subtaxa.new(
      name: @genus, children_query: stub_query, controller: nil
    )

    assert_equal(:show_object.t(type: :rank_species), tab.title)
  end

  def test_subtaxa_title_fallback_when_species_or_below
    # Species is at_or_below_species → fallback label.
    tab = Tab::Name::Subtaxa.new(
      name: @species, children_query: stub_query, controller: nil
    )

    assert_equal(:show_object.t(type: :show_subtaxa_obss), tab.title)
  end

  def test_subtaxa_query_is_the_injected_children_query
    inj = stub_query
    tab = Tab::Name::Subtaxa.new(
      name: @genus, children_query: inj, controller: nil
    )

    assert_same(inj, tab.query)
  end

  # --- Tab::Name::RefreshClassification ------------------------

  def test_refresh_visible_when_below_genus_and_classification_diverges
    # Stub: accepted genus has different classification.
    @species.define_singleton_method(:accepted_genus) do
      Object.new.tap do |g|
        g.define_singleton_method(:classification) { "Phylum: Different" }
      end
    end
    @species.classification = "Phylum: Original"

    assert(Tab::Name::RefreshClassification.visible_for?(name: @species))
    assert_kind_of(Tab::Name::RefreshClassification,
                   Tab::Name::RefreshClassification.for(name: @species))
  end

  def test_refresh_not_visible_when_above_genus
    assert_not(Tab::Name::RefreshClassification.visible_for?(name: @genus))
    assert_nil(Tab::Name::RefreshClassification.for(name: @genus))
  end

  def test_refresh_path_and_html_options
    tab = Tab::Name::RefreshClassification.new(name: @species)

    assert_equal(refresh_classification_of_name_path(@species.id), tab.path)
    assert_equal(:put, tab.html_options[:button])
  end

  # --- Tab::Name::PropagateClassification ----------------------

  def test_propagate_visible_when_can_propagate_and_classification_present
    @genus.classification = "Phylum: _Foo_"
    @genus.define_singleton_method(:can_propagate?) { true }

    assert(Tab::Name::PropagateClassification.visible_for?(name: @genus))
  end

  def test_propagate_not_visible_when_classification_blank
    @genus.classification = ""
    @genus.define_singleton_method(:can_propagate?) { true }

    assert_not(Tab::Name::PropagateClassification.visible_for?(name: @genus))
    assert_nil(Tab::Name::PropagateClassification.for(name: @genus))
  end

  def test_propagate_path_and_html_options
    tab = Tab::Name::PropagateClassification.new(name: @genus)

    assert_equal(propagate_classification_of_name_path(@genus.id),
                 tab.path)
    assert_equal(:put, tab.html_options[:button])
  end

  # --- Tab::Name::InheritClassification ------------------------

  def test_inherit_visible_when_genus_or_above_without_classification
    @genus.classification = ""

    assert(Tab::Name::InheritClassification.visible_for?(name: @genus))
  end

  def test_inherit_not_visible_when_classification_present
    @genus.classification = "Phylum: _Foo_"

    assert_not(Tab::Name::InheritClassification.visible_for?(name: @genus))
    assert_nil(Tab::Name::InheritClassification.for(name: @genus))
  end

  def test_inherit_not_visible_when_below_genus
    @species.classification = ""

    assert_not(Tab::Name::InheritClassification.visible_for?(name: @species))
  end

  def test_inherit_path_is_form_path
    tab = Tab::Name::InheritClassification.new(name: @genus)

    assert_equal(form_to_inherit_classification_of_name_path(@genus.id),
                 tab.path)
  end

  private

  # `Tab::QueryLink` reads `query` (memoized via `build_query`),
  # so we just need an object that responds to nothing in the
  # title/visibility tests.
  def stub_query
    Object.new
  end

  def refresh_classification_of_name_path(id)
    Rails.application.routes.url_helpers.refresh_classification_of_name_path(id)
  end

  def propagate_classification_of_name_path(id)
    Rails.application.routes.url_helpers.
      propagate_classification_of_name_path(id)
  end

  def form_to_inherit_classification_of_name_path(id)
    Rails.application.routes.url_helpers.
      form_to_inherit_classification_of_name_path(id)
  end
end
