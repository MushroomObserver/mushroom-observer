# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Herbaria
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
      controller.define_singleton_method(:index_sort_options) { [] }
    end

    # Without merge mode: admin actions (Edit + Merge GET links) render
    # for herbariums the current user can edit.
    def test_admin_actions_render_edit_and_merge_links
      herb = herbaria(:rolf_herbarium)
      html = render_index(objects: [herb])

      assert_html(html,
                  "a[href='#{routes.edit_herbarium_path(herb)}']" \
                  ".edit_herbarium_link_#{herb.id}")
      assert_html(html,
                  "a[href='#{routes.herbaria_path(merge: herb.id)}']" \
                  ".merge_herbarium_link_#{herb.id}")
    end

    # Merge mode: herbarium rows become POST forms pointing at the
    # merge-action path.
    def test_merge_mode_renders_post_form_for_other_herbaria
      src = herbaria(:rolf_herbarium)
      dest = herbaria(:nybg_herbarium)
      html = render_index(objects: [dest], merge: src)

      # The NON-merge source renders as a POST form targeting the
      # merges path.
      merge_path = routes.herbaria_merges_path(src: src.id, dest: dest.id)
      assert_html(html, "form[action='#{merge_path}']")
      assert_html(html,
                  ".herbaria_merges_link_#{src.id}_#{dest.id}")
    end

    private

    def render_index(objects:, merge: nil)
      render(Index.new(
               query: Query.lookup_and_save(:Herbarium),
               pagination_data: PaginationData.new,
               objects: objects,
               merge: merge
             ))
    end
  end
end
