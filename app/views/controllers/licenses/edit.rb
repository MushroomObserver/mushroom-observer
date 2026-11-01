# frozen_string_literal: true

module Views::Controllers::Licenses
  # Edit-license page — registers chrome and delegates to the
  # existing `Licenses::Form`.
  class Edit < Views::FullPageBase
    prop :license, ::License

    def view_template
      add_page_title(edit_title)
      add_context_nav(::Tab::License::FormEdit.new(license: @license))

      render(Form.new(@license, turbo: true))
    end

    private

    # "Editing: <display_name> #(id):"
    def edit_title
      capture do
        trusted_html(append_colon(:editing.ti))
        trusted_html(show_title_html)
      end
    end

    def show_title_html
      [
        @license.display_name,
        capture do
          span(class: "smaller") do
            span { append_colon("#(#{@license.id || "?"})") }
          end
        end
      ].safe_join(" ")
    end
  end
end
