# frozen_string_literal: true

# Action template for the CollectionNumbers index. Replaces
# `app/views/controllers/collection_numbers/index.html.erb`.
#
# `CollectionNumbersController#render_index_view` overrides the
# `ApplicationController` default to render this class directly with
# explicit props.
module Views::Controllers::CollectionNumbers
  class Index < Views::FullPageBase
    prop :query, ::Query::CollectionNumbers
    prop :pagination_data, ::PaginationData
    prop :objects, _Array(::CollectionNumber)
    prop :user, ::User
    prop :observation, _Nilable(::Observation), default: nil
    prop :error, _Nilable(String), default: nil

    def view_template
      container_class(:wide)
      add_index_title(@query)
      add_context_nav(
        Tab::CollectionNumber::IndexActions.new(observation: @observation)
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
      render(Components::Table.new(@objects, class: "table-striped mt-3",
                                             show_headers: false)) do |t|
        t.column("") { |cn| render_edit_link(cn) }
        t.column("") { |cn| render_format_name_link(cn) }
        t.column("") { |cn| render_observation_links(cn) }
        t.column("") { |cn| render_delete_button(cn) }
      end
    end

    def render_edit_link(collection_number)
      return unless can_edit?(collection_number)

      a(href: edit_collection_number_path(id: collection_number.id,
                                          params: { back: :index }),
        class: "btn btn-default btn-sm") { plain(:EDIT.t) }
    end

    def render_format_name_link(collection_number)
      i do
        a(href: collection_number_path(collection_number)) do
          trusted_html(collection_number.format_name.t)
        end
      end
    end

    def render_observation_links(collection_number)
      collection_number.observations.each_with_index do |obs, idx|
        plain(", ") if idx.positive?
        a(href: observation_path(obs)) do
          trusted_html(obs.unique_format_name.t)
        end
      end
    end

    def render_delete_button(collection_number)
      return unless can_edit?(collection_number)

      render(Components::CrudButton::Delete.new(
               target: collection_number, class: "btn-sm"
             ))
    end

    def can_edit?(collection_number)
      in_admin_mode? || collection_number.can_edit?(@user)
    end
  end
end
