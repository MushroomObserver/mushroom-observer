# frozen_string_literal: true

require("test_helper")

module Tab::FieldSlip
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @field_slip = field_slips(:field_slip_one)
    end

    def test_index
      tab = Tab::FieldSlip::Index.new

      assert_equal(:index_object.ti(type: :field_slips), tab.title)
      assert_equal(routes.field_slips_path, tab.path)
      assert_equal(FieldSlip, tab.model)
    end

    def test_new
      tab = Tab::FieldSlip::New.new

      assert_equal(:field_slip_new.t, tab.title)
      assert_equal(routes.new_field_slip_path, tab.path)
      assert_equal(FieldSlip, tab.model)
    end

    def test_show
      tab = Tab::FieldSlip::Show.new(field_slip: @field_slip)

      assert_equal(:show_object.t(type: :field_slip), tab.title)
      assert_equal(routes.field_slip_path(@field_slip), tab.path)
      assert_equal(@field_slip, tab.model)
    end
  end

  class CollectionsTest < UnitTestCase
    def setup
      @field_slip = field_slips(:field_slip_one)
    end

    def test_index_actions
      tabs = Tab::FieldSlip::IndexActions.new.to_a

      assert_equal([Tab::FieldSlip::New], tabs.map(&:class))
    end

    def test_form_edit
      tabs = Tab::FieldSlip::FormEdit.new(field_slip: @field_slip).to_a

      assert_equal(
        [Tab::FieldSlip::Index, Tab::FieldSlip::Show],
        tabs.map(&:class)
      )
    end
  end
end
