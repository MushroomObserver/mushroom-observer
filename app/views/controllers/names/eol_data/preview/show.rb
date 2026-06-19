# frozen_string_literal: true

# Action template for `Names::EolData::PreviewController#show`.
# Striped list of names that are `ok_for_export`, plus a final
# count.
class Views::Controllers::Names::EolData::Preview::Show < Views::FullPageBase
  prop :names, _Array(::Name)

  def view_template
    add_page_title(:eol_preview_title.t)
    trusted_html(:eol_preview_explanation.tp)
    render_name_rows
    render_count_paragraph
  end

  private

  def render_name_rows
    odd_or_even = 0
    @names.select(&:ok_for_export).each do |name|
      odd_or_even = 1 - odd_or_even
      div(class: "ListLine#{odd_or_even} py-10px") do
        # Preserve textile-rendered italics/bold for scientific
        # names — `display_name.t` emits HTML, so trusted_html is
        # required (plain text would double-escape the tags).
        trusted_html(name.display_name.t)
      end
    end
  end

  def render_count_paragraph
    p do
      plain(:eol_preview_name_count.t(count: @names.length))
      br
    end
  end
end
