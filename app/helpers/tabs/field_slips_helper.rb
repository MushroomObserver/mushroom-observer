# frozen_string_literal: true

module Tabs
  module FieldSlipsHelper
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
      InternalLink::Model.new(
        :field_slip_index.t, FieldSlip, field_slips_path
      ).tab
    end

    def new_field_slip_tab
      InternalLink::Model.new(
        :field_slip_new.t, FieldSlip, new_field_slip_path
      ).tab
    end

    def show_field_slip_tab(field_slip)
      InternalLink::Model.new(
        :field_slip_show.t, field_slip, field_slip_path(field_slip)
      ).tab
    end

    def edit_field_slip_tab(field_slip)
      InternalLink::Model.new(
        :field_slip_edit.t, field_slip, edit_field_slip_path(field_slip)
      ).tab
    end

    def destroy_field_slip_tab(field_slip)
      InternalLink::Model.new(
        :destroy_object.t(type: :field_slip), field_slip, field_slip,
        html_options: { button: :destroy }
      ).tab
    end
  end
end
