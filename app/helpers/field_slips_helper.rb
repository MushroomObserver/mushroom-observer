# frozen_string_literal: true

module FieldSlipsHelper
  def last_observation
    return unless User.current

    ObservationView.last(User.current)
  end

  def field_slip_show_tabs(field_slip)
    links = [field_slips_index_tab, new_field_slip_tab]
    return links unless field_slip.can_edit?

    links.push(edit_field_slip_tab(field_slip),
               destroy_field_slip_tab(field_slip))
  end

  def field_slip_edit_tabs(field_slip)
    [field_slips_index_tab, show_field_slip_tab(field_slip)]
  end

  def field_slips_index_tabs
    [new_field_slip_tab]
  end

  def field_slips_index_tab
    [:field_slip_index.t, field_slips_path, { class: tab_id(__method__.to_s) }]
  end

  def new_field_slip_tab
    [:field_slip_new.t, new_field_slip_path, { class: tab_id(__method__.to_s) }]
  end

  def show_field_slip_tab(field_slip)
    [:field_slip_show.t, field_slip_path(field_slip), { class: tab_id(__method__.to_s) }]
  end

  def edit_field_slip_tab(field_slip)
    [:field_slip_edit.t, edit_field_slip_path(field_slip),
     { class: tab_id(__method__.to_s) }]
  end

  def destroy_field_slip_tab(field_slip)
    [nil, field_slip, { button: :destroy }]
  end
end
