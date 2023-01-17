# frozen_string_literal: true

require("test_helper")
require("set")

module Locations::Descriptions
  class MergesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_try_merge_descriptions_no_permission; end

    def test_merge_descriptions; end

    def test_merge_descriptions_notes_conflict; end

    def test_merge_incompatible_descriptions; end
  end
end
