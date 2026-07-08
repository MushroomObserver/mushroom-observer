# frozen_string_literal: true

require("test_helper")

# TEMPORARY — HTML parity check for the Components::InputGroup /
# Components::ButtonGroup conversion. Same pattern as
# navbar_component_parity_test.rb: each "Old" subclass overrides only
# the specific private method(s) touched by that PR with their
# pre-conversion bodies, leaving everything else inherited from the
# real, current class.
#
# Delete this whole file once the PR is confirmed to introduce no
# HTML drift — see ".claude/rules/phlex_reference.md" parity-harness
# patterns ("Delete the `_Old` copy and the parity test together").
module Views::Layouts
  class InputGroupButtonGroupParityTest < ComponentTestCase
    # ---- header/index_pagination_nav.rb (input-group) -------------------

    class Header::IndexPaginationNavOld2 < Header::IndexPaginationNav
      private

      def render_page_input_group(this_page, max_page)
        div(class: "input-group page-input mx-2") do
          input(**page_input_attrs(this_page, max_page))
          render_goto_button
        end
      end

      def render_goto_button
        span(class: "input-group-btn") do
          Button(
            type: :submit,
            variant: :outline,
            class: "px-2"
          ) { Icon(type: :goto, title: :GOTO.l) }
        end
      end
    end

    def test_index_pagination_nav_input_group_parity
      request_url = "/observations?q%5Bmodel%5D=Observation"
      form_action_url = "http://test.host/observations"
      pagination_data = ::PaginationData.new(
        number: 1, num_per_page: 10, num_total: 50, number_arg: :page
      )

      old_html = render(Header::IndexPaginationNavOld2.new(
                          position: :top, request_url: request_url,
                          form_action_url: form_action_url,
                          pagination_data: pagination_data
                        ))
      new_html = render(Header::IndexPaginationNav.new(
                          position: :top, request_url: request_url,
                          form_action_url: form_action_url,
                          pagination_data: pagination_data
                        ))

      assert_html_element_equivalent(
        old_html, new_html,
        selector: "div.input-group", label: "index_pagination_input_group"
      )
    end
  end
end

module Views::Controllers::Account::APIKeys
  class FormParityTest < ComponentTestCase
    class FormOld < ::Views::Controllers::Account::APIKeys::Form
      private

      def render_table_layout
        label(for: field(:notes).dom.id) { :account_api_keys_notes_label.t }

        div(class: "input-group") do
          render_cancel_button if @cancel_target

          text_field(:notes, label: false, size: 40,
                             class: "form-control border-none")

          span(class: "input-group-btn") do
            submit(:CREATE.l, submits_with: submits_text)
          end
        end
      end

      def render_inline_edit_layout
        div(class: "input-group") do
          render_cancel_button

          text_field(:notes, label: false,
                             id: "api_key_#{model.id}_notes",
                             class: "form-control border-none")

          span(class: "input-group-btn") do
            submit(:SAVE.l, submits_with: submits_text)
          end
        end
      end

      def render_cancel_button
        span(class: "input-group-btn") do
          Link(type: :collapse_toggle,
               target_id: @cancel_target,
               collapsed: false,
               icon: :cancel,
               icon_title: :CANCEL.l,
               button: :default,
               data: { parent: "##{@cancel_parent}" })
        end
      end
    end

    def setup
      super
      @api_key = APIKey.new
    end

    def test_table_layout_parity
      old_html = render(FormOld.new(
                          @api_key, action: "/x", id: "f",
                                    cancel_target: "t", cancel_parent: "p"
                        ))
      new_html = render(Form.new(
                          @api_key, action: "/x", id: "f",
                                    cancel_target: "t", cancel_parent: "p"
                        ))

      assert_html_element_equivalent(old_html, new_html,
                                     selector: "div.input-group",
                                     label: "api_key_table_layout")
    end

    def test_inline_edit_layout_parity
      key = api_keys(:rolfs_api_key)

      old_html = render(FormOld.new(
                          key, action: "/x", id: "f",
                               cancel_target: "t", cancel_parent: "p"
                        ))
      new_html = render(Form.new(
                          key, action: "/x", id: "f",
                               cancel_target: "t", cancel_parent: "p"
                        ))

      assert_html_element_equivalent(old_html, new_html,
                                     selector: "div.input-group",
                                     label: "api_key_inline_edit_layout")
    end
  end
end

module Views::Controllers::RssLogs
  class TypeFiltersParityTest < ComponentTestCase
    class TypeFiltersOld < ::Views::Controllers::RssLogs::TypeFilters
      private

      def render_filter_buttons
        div(class: "px-3 pb-1 hidden-xs text-nowrap") do
          render_show_label
          div(class: "btn-group") do
            render_everything_button
            render_type_buttons
            render_submit_button
          end
        end
      end
    end

    def test_type_filters_parity
      old_html = render(TypeFiltersOld.new(query: nil, types: ["all"]))
      new_html = render(TypeFilters.new(query: nil, types: ["all"]))

      # ButtonGroup's one intentional behavior change: it always emits
      # `role="group"`, which this raw `.btn-group` div never had.
      # Confirm that deliberate diff explicitly, then strip it from
      # both sides before checking everything else is unchanged.
      assert_no_html(old_html, "div.btn-group[role]")
      assert_html(new_html, "div.btn-group[role='group']")

      assert_html_element_equivalent(
        old_html.gsub(' role="group"', ""), new_html.gsub(' role="group"', ""),
        selector: "form", label: "type_filters"
      )
    end
  end
end

module Views::Controllers::Interests
  class IndexParityTest < ComponentTestCase
    class IndexOld < ::Views::Controllers::Interests::Index
      private

      def render_type_filter
        div(class: "btn-group pb-1 hidden-xs text-nowrap mt-5") do
          Button(
            name: :rss_show.l, tag: :span, size: :sm,
            class: "disabled"
          )
          render_filter_pill(nil, :rss_all.l, interests_path)
          @types.each do |type|
            label = type.underscore.pluralize.upcase.to_sym.l
            render_filter_pill(type, label, interests_path(type: type))
          end
        end
      end
    end

    def setup
      super
      controller.instance_variable_set(:@user, users(:rolf))
    end

    def test_interests_index_type_filter_parity
      old_html = render(IndexOld.new(
                          interests: [], types: %w[Observation Name],
                          selected_type: "Observation",
                          pagination_data: PaginationData.new
                        ))
      new_html = render(Index.new(
                          interests: [], types: %w[Observation Name],
                          selected_type: "Observation",
                          pagination_data: PaginationData.new
                        ))

      # ButtonGroup's one intentional behavior change: it always emits
      # `role="group"`, which this raw `.btn-group` div never had.
      assert_no_html(old_html, "div.btn-group[role]")
      assert_html(new_html, "div.btn-group[role='group']")

      assert_html_element_equivalent(
        old_html.gsub(' role="group"', ""), new_html.gsub(' role="group"', ""),
        selector: "div.btn-group", label: "interests_type_filter"
      )
    end
  end
end

module Views::Controllers::VisualGroups
  class EditParityTest < ComponentTestCase
    class EditOld < ::Views::Controllers::VisualGroups::Edit
      private

      def render_status_button_row
        div(class: "d-flex gap-2 align-items-center mb-3") do
          strong(class: "mb-0") do
            plain("#{:edit_visual_group_filter_options.t}:")
          end
          div(class: "btn-group", role: "group") do
            STATUSES.each do |(value, label_key)|
              render_status_button(value, label_key.t)
            end
          end
          render_reload_link if @status == "needs_review"
        end
      end
    end

    def test_visual_group_status_button_row_parity
      vg = visual_groups(:visual_group_one)

      old_html = render(EditOld.new(
                          visual_group: vg, user: users(:rolf),
                          status: "needs_review"
                        ))
      new_html = render(Edit.new(
                          visual_group: vg, user: users(:rolf),
                          status: "needs_review"
                        ))

      assert_html_element_equivalent(
        old_html, new_html,
        selector: "div.btn-group", label: "visual_group_status_buttons"
      )
    end
  end
end
