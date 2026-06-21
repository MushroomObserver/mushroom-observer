# frozen_string_literal: true

require("test_helper")

module Views::Controllers::HerbariumRecords
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      controller.define_singleton_method(:index_sort_options) { [] }
    end

    # The edit link renders as a GET <a> with the identifier class
    # `edit_herbarium_record_link_{id}` used for JS/Turbo targeting.
    def test_edit_link_navigates_to_edit_path
      rec = herbarium_records(:coprinus_comatus_nybg_spec) # owned by rolf
      html = render_index(objects: [rec])

      assert_html(html,
                  "a[href*='/herbarium_records/#{rec.id}/edit']" \
                  ".edit_herbarium_record_link_#{rec.id}")
    end

    def test_no_edit_link_when_user_cannot_edit
      # `interesting_unknown` herbarium record is owned by rolf, so use
      # a record rolf does not own. The nybg herbarium records all have
      # user: rolf; use a different herbarium's record.
      rec = herbarium_records(:coprinus_comatus_rolf_spec)
      # rolf owns this too — use mary as the test user instead
      controller.instance_variable_set(:@user, users(:mary))
      html = render_index(objects: [rec])

      assert_no_html(html, "a[href*='/herbarium_records/#{rec.id}/edit']")
    end

    private

    def render_index(objects:)
      render(Index.new(
               query: Query.lookup_and_save(:HerbariumRecord),
               pagination_data: PaginationData.new,
               objects: objects,
               user: controller.instance_variable_get(:@user)
             ))
    end
  end
end
