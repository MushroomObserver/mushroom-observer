# frozen_string_literal: true

require("test_helper")

module Tab::HerbariumRecord
  class CollectionsTest < UnitTestCase
    def setup
      @herbarium_record = herbarium_records(:coprinus_comatus_nybg_spec)
      @observation = @herbarium_record.observations.first
    end

    def test_index_actions_without_observation
      tabs = Tab::HerbariumRecord::IndexActions.new.to_a

      assert_equal(
        [Tab::Herbarium::New, Tab::Herbarium::NonpersonalIndex],
        tabs.map(&:class)
      )
    end

    def test_index_actions_with_observation
      tabs = Tab::HerbariumRecord::IndexActions.new(
        observation: @observation
      ).to_a

      assert_equal(
        [Tab::Object::Return, Tab::Herbarium::New,
         Tab::Herbarium::NonpersonalIndex],
        tabs.map(&:class)
      )
    end

    def test_show_actions
      tabs = Tab::HerbariumRecord::ShowActions.new.to_a

      assert_equal([Tab::Herbarium::NonpersonalIndex], tabs.map(&:class))
    end

    def test_form_new
      tabs = Tab::HerbariumRecord::FormNew.new(
        observation: @observation
      ).to_a

      assert_equal(
        [Tab::Object::Return, Tab::Herbarium::New,
         Tab::Herbarium::NonpersonalIndex],
        tabs.map(&:class)
      )
    end

    def test_form_edit_from_index
      tabs = Tab::HerbariumRecord::FormEdit.new(
        back: "index", back_object: nil
      ).to_a

      assert_equal(
        [Tab::HerbariumRecord::BackToIndex, Tab::Herbarium::New,
         Tab::Herbarium::NonpersonalIndex],
        tabs.map(&:class)
      )
    end

    def test_form_edit_with_back_object
      tabs = Tab::HerbariumRecord::FormEdit.new(
        back: "show", back_object: @observation
      ).to_a

      assert_equal(
        [Tab::Object::Return, Tab::Herbarium::New,
         Tab::Herbarium::NonpersonalIndex],
        tabs.map(&:class)
      )
    end

    # back != "index" AND back_object nil → back_link returns nil and the
    # leading slot is compacted out, leaving just the standard 2 herbaria
    # tabs.
    def test_form_edit_no_back_link
      tabs = Tab::HerbariumRecord::FormEdit.new(
        back: "show", back_object: nil
      ).to_a

      assert_equal(
        [Tab::Herbarium::New, Tab::Herbarium::NonpersonalIndex],
        tabs.map(&:class)
      )
    end
  end
end
