# frozen_string_literal: true

require("test_helper")

# Output-parity test: for each converted Tab PORO, assert that
# `pororo.to_a` produces the *same* `[title, url, html_options]`
# array the pre-conversion `Tabs::HerbariaHelper` method would have
# returned. The right-hand-side InternalLink constructions below
# are byte-for-byte copies of the original helper-method bodies —
# any silent drift in the conversion (URL encoding, options
# ordering, InternalLink::Model vs InternalLink) fails the
# matching assertion.
#
# This file exists for the migration window and can be deleted
# once the old helper methods are gone from every helper file.
module Tab::Herbarium
  class ParityTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @herbarium = herbaria(:nybg_herbarium)
    end

    def test_new
      expected = ::InternalLink::Model.new(
        :create_herbarium.l, Herbarium,
        routes.new_herbarium_path, alt_title: "new_herbarium"
      ).tab

      actual = Tab::Herbarium::New.new.to_a

      assert_equal(expected, actual)
    end

    def test_list_all
      expected = ::InternalLink::Model.new(
        :herbarium_index_list_all_herbaria.l, Herbarium, routes.herbaria_path
      ).tab

      actual = Tab::Herbarium::ListAll.new.to_a

      assert_equal(expected, actual)
    end

    def test_return
      expected = ::InternalLink::Model.new(
        :cancel_and_show.t(type: :herbarium), @herbarium,
        routes.herbarium_path(@herbarium)
      ).tab

      actual = Tab::Herbarium::Return.new(herbarium: @herbarium).to_a

      assert_equal(expected, actual)
    end

    def test_nonpersonal_index_no_q_param
      expected = ::InternalLink.new(
        :herbarium_index.t,
        routes.herbaria_path(nonpersonal: true),
        alt_title: "nonpersonal_herbaria_index"
      ).tab

      actual = Tab::Herbarium::NonpersonalIndex.new.to_a

      assert_equal(expected, actual)
    end

    def test_nonpersonal_index_with_q_param
      expected = ::InternalLink.new(
        :herbarium_index.t,
        routes.herbaria_path(nonpersonal: true, q: "X"),
        alt_title: "nonpersonal_herbaria_index"
      ).tab

      actual = Tab::Herbarium::NonpersonalIndex.new(q_param: "X").to_a

      assert_equal(expected, actual)
    end

    def test_labeled_nonpersonal_index
      expected = ::InternalLink.new(
        :herbarium_index_nonpersonal_herbaria.l,
        routes.herbaria_path(nonpersonal: true)
      ).tab

      actual = Tab::Herbarium::LabeledNonpersonalIndex.new.to_a

      assert_equal(expected, actual)
    end
  end
end
