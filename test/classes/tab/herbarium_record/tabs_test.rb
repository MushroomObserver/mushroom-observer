# frozen_string_literal: true

require("test_helper")

module Tab::HerbariumRecord
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @herbarium_record = herbarium_records(:coprinus_comatus_nybg_spec)
      @observation = @herbarium_record.observations.first
    end

    def test_show_without_observation
      tab = Tab::HerbariumRecord::Show.new(
        herbarium_record: @herbarium_record
      )

      assert_equal(@herbarium_record.accession_at_herbarium.t, tab.title)
      assert_equal(@herbarium_record.show_link_args, tab.path)
      assert_equal("herbarium_record", tab.alt_title)
    end

    def test_show_with_observation
      tab = Tab::HerbariumRecord::Show.new(
        herbarium_record: @herbarium_record, observation: @observation
      )

      assert(tab.path[:q].present?)
    end

    def test_new
      tab = Tab::HerbariumRecord::New.new(observation: @observation)

      assert_equal(:add_object.t(type: :herbarium_record), tab.title)
      assert_equal(
        routes.new_herbarium_record_path(observation_id: @observation.id),
        tab.path
      )
      assert_equal(Herbarium, tab.model)
    end

    def test_edit_back_to_observation
      tab = Tab::HerbariumRecord::Edit.new(
        herbarium_record: @herbarium_record, observation: @observation
      )

      assert_equal(
        routes.edit_herbarium_record_path(
          @herbarium_record.id, back: @observation.id
        ),
        tab.path
      )
    end

    def test_edit_back_to_show
      tab = Tab::HerbariumRecord::Edit.new(
        herbarium_record: @herbarium_record
      )

      assert_equal(
        routes.edit_herbarium_record_path(@herbarium_record.id, back: :show),
        tab.path
      )
    end

    def test_back_to_index_without_q_param
      tab = Tab::HerbariumRecord::BackToIndex.new

      assert_equal(:edit_herbarium_record_back_to_index.l, tab.title)
      assert_equal(routes.herbarium_records_path, tab.path)
    end

    def test_back_to_index_with_q_param
      tab = Tab::HerbariumRecord::BackToIndex.new(q_param: "ABCDE")

      assert_equal(routes.herbarium_records_path(q: "ABCDE"), tab.path)
    end
  end
end
