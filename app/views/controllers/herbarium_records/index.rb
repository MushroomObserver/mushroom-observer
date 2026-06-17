# frozen_string_literal: true

# Action template for the HerbariumRecords index. Replaces
# `app/views/controllers/herbarium_records/index.html.erb`.
#
# `HerbariumRecordsController#render_index_view` overrides the
# `ApplicationController` default to render this class directly
# with explicit props.
module Views::Controllers::HerbariumRecords
  class Index < Views::Base
    prop :query, ::Query::HerbariumRecords
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::HerbariumRecord)
    prop :user, ::User
    prop :observation, _Nilable(::Observation), default: nil
    prop :error, _Nilable(String), default: nil

    def view_template
      container_class(:wide)
      add_index_title(@query)
      add_context_nav(
        Tab::HerbariumRecord::IndexActions.new(
          observation: @observation, q_param: q_param
        )
      )
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)

      flash_error(@error) if @error && @objects.empty?

      paginated_results { render_rows_table if @objects.any? }
    end

    private

    # Headerless `Components::Table` (`show_headers: false`) — matches
    # the bare-table markup of the original ERB.
    def render_rows_table
      render(Components::Table.new(@objects, class: "table-striped",
                                             show_headers: false)) do |t|
        t.column("") { |rec| render_edit_link(rec) }
        t.column("") { |rec| render_herbarium_link(rec) }
        t.column("") { |rec| render_record_link(rec) }
        t.column("") { |rec| render_observation_links(rec) }
        t.column("") { |rec| render_delete_button(rec) }
      end
    end

    def render_edit_link(rec)
      return unless can_edit?(rec)

      a(href: edit_herbarium_record_path(id: rec.id, back: :index,
                                         q: q_param),
        class: "btn btn-default btn-sm edit_herbarium_record_link_#{rec.id}") do
        plain(:EDIT.t)
      end
    end

    def render_herbarium_link(rec)
      # `herbarium_records.herbarium_id` is `NOT NULL` at the schema
      # level, so `rec.herbarium` is always present here.
      a(href: herbarium_path(rec.herbarium.id)) do
        trusted_html(rec.herbarium.name.t)
      end
    end

    def render_record_link(rec)
      a(href: herbarium_record_path(id: rec.id),
        class: "herbarium_record_link_#{rec.id}") do
        trusted_html(rec.herbarium_label.t)
      end
    end

    def render_observation_links(rec)
      rec.observations.each_with_index do |obs, idx|
        plain(", ") if idx.positive?
        a(href: observation_path(obs.id)) do
          trusted_html(obs.unique_format_name.t)
        end
      end
    end

    def render_delete_button(rec)
      return unless can_edit?(rec)

      render(Components::CrudButton::Delete.new(
               target: herbarium_record_path(rec.id, back: :index),
               name: :destroy_object.t(type: :herbarium_record),
               class: "btn-sm destroy_herbarium_record_link_#{rec.id}"
             ))
    end

    def can_edit?(rec)
      in_admin_mode? || rec.can_edit?(@user)
    end
  end
end
