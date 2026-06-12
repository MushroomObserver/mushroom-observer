# frozen_string_literal: true

require("test_helper")

module Tab::GlossaryTerm
  class CollectionsTest < UnitTestCase
    def setup
      @term = glossary_terms(:conic_glossary_term)
    end

    def test_form_new
      tabs = Tab::GlossaryTerm::FormNew.new.to_a

      assert_equal([Tab::GlossaryTerm::Index], tabs.map(&:class))
    end

    def test_form_edit
      tabs = Tab::GlossaryTerm::FormEdit.new(term: @term).to_a

      assert_equal(
        [Tab::Object::Return, Tab::GlossaryTerm::Index],
        tabs.map(&:class)
      )
    end

    def test_image_form
      tabs = Tab::GlossaryTerm::ImageForm.new(term: @term).to_a

      assert_equal(
        [Tab::Object::Return, Tab::GlossaryTerm::Edit],
        tabs.map(&:class)
      )
    end

    def test_version_actions
      tabs = Tab::GlossaryTerm::VersionActions.new(term: @term).to_a

      assert_equal([Tab::GlossaryTerm::Show], tabs.map(&:class))
    end
  end
end
