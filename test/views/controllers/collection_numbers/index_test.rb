# frozen_string_literal: true

require("test_helper")

module Views::Controllers::CollectionNumbers
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      controller.define_singleton_method(:index_sort_options) { [] }
    end

    # The edit link renders as a GET <a> pointing at the edit path
    # for collection numbers the current user can edit.
    def test_edit_link_navigates_to_edit_path
      cn = collection_numbers(:coprinus_comatus_coll_num) # owned by rolf
      html = render_index(objects: [cn])

      assert_html(html, "a[href*='/collection_numbers/#{cn.id}/edit']")
    end

    def test_no_edit_link_for_collection_number_user_cannot_edit
      cn = collection_numbers(:minimal_unknown_coll_num) # owned by mary
      html = render_index(objects: [cn])

      assert_no_html(html, "a[href*='/collection_numbers/#{cn.id}/edit']")
    end

    private

    def render_index(objects:)
      render(Index.new(
               query: Query.lookup_and_save(:CollectionNumber),
               pagination_data: PaginationData.new,
               objects: objects,
               user: @user
             ))
    end
  end
end
