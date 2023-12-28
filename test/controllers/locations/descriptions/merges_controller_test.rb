# frozen_string_literal: true

require("test_helper")

module Locations::Descriptions
  class MergesControllerTest < FunctionalTestCase
    include ObjectLinkHelper

    def test_form_permissions; end

    def test_merge_descriptions_no_permission; end

    def test_merge_descriptions_notes_conflict; end

    def test_merge_with_nonexistant_description; end
  end
end
