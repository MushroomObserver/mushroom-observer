# frozen_string_literal: true

# Action template for the HerbariumRecords index.
#
# `HerbariumRecordsController#render_index_view` overrides the
# `ApplicationController` default to render this class directly
# with explicit props.
module Views::Controllers::HerbariumRecords
  class Index < Views::FullPageBase
    prop :query, ::Query::HerbariumRecords
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::HerbariumRecord)
    prop :user, ::User
    prop :observation, _Nilable(::Observation), default: nil

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

      PaginatedResults do
        render_rows_table if @objects.any?
      end
    end

    private

    def render_rows_table
      Table(@objects, variant: :striped,
                      identifier: "herbarium_record") do |t|
        build_table_columns(t)
      end
    end

    def build_table_columns(table)
      table.column(:herbarium.ti) { |rec| render_herbarium_link(rec) }
      table.column(:label.ti) { |rec| render_record_link(rec) }
      table.column(:observations.ti) { |rec| render_observation_links(rec) }
      build_trailing_columns(table)
    end

    def build_trailing_columns(table)
      table.column(nil, align: :center) { |rec| render_actions(rec) }
      table.column(:mo_id.ti, align: :right) do |rec|
        render_id_badge(rec)
      end
    end

    def render_actions(rec)
      InlineCRUDLinks(target: rec, observation: @observation, user: @user)
    end

    def render_id_badge(rec)
      Badge(variant: :id, object: rec, size: :lg, extra_class: nil)
    end

    def render_herbarium_link(rec)
      # `herbarium_records.herbarium_id` is `NOT NULL` at the schema
      # level, so `rec.herbarium` is always present here.
      Link(type: :object, object: rec.herbarium, name: rec.herbarium.name.t)
    end

    def render_record_link(rec)
      Link(type: :object, object: rec, name: rec.herbarium_label.t)
    end

    def render_observation_links(rec)
      rec.observations.each_with_index do |obs, idx|
        plain(", ") if idx.positive?
        Link(type: :get, name: viewer_aware_unique_format_name(obs).t,
             target: permanent_observation_path(obs.id)) do
          trusted_html(viewer_aware_unique_format_name(obs).t)
        end
      end
    end
  end
end
