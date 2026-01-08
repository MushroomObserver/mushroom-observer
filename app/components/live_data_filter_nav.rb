# frozen_string_literal: true

# Navigation component for filtering and paginating in-memory data.
# Uses Turbo Frames for live updates without full page reload.
#
# Note: The controller action must handle the pagination and filter params
# passed via prev_path/next_path (e.g., :page, :starts_with). The action
# should filter and paginate the data accordingly.
#
# Usage:
#   render(Components::LiveDataFilterNav.new(
#     page: 1,
#     total_pages: 5,
#     prev_path: my_path(page: 0),
#     next_path: my_path(page: 2)
#   )) do |nav|
#     nav.with_form do
#       # render your filter form here
#     end
#   end
#
class Components::LiveDataFilterNav < Components::Base
  include Phlex::Slotable

  prop :page, Integer, default: 1
  prop :total_pages, Integer, default: 1
  prop :prev_path, _Nilable(String)
  prop :next_path, _Nilable(String)

  slot :form

  def view_template
    nav(class: "d-flex justify-content-between align-items-center") do
      render_prev_button
      render(form_slot) if form_slot?
      render_next_button
    end
  end

  private

  def render_prev_button
    link_to(
      "« Prev",
      @prev_path || "#",
      class: class_names("btn btn-default btn-sm", "opacity-0": !show_prev?),
      disabled: !show_prev?
    )
  end

  def render_next_button
    link_to(
      "Next »",
      @next_path || "#",
      class: class_names("btn btn-default btn-sm", "opacity-0": !show_next?),
      disabled: !show_next?
    )
  end

  def show_prev?
    @page > 1
  end

  def show_next?
    @page < @total_pages
  end
end
