# frozen_string_literal: true

module Views::Controllers::Users
  # Users index — admins see a verification/groups/last-login table;
  # everyone else sees the matrix of user thumbnails.
  class Index < Views::Base
    prop :query, ::Query
    prop :users, _Array(::User)
    prop :pagination_data, ::PaginationData
    prop :error, _Nilable(::String), default: nil

    def view_template
      container_class(:full)
      add_index_title(@query)
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)
      flash_error(@error) if @error && @users.empty?

      if in_admin_mode?
        render_admin_table
      else
        paginated_results do
          render(::Components::MatrixTable.new(objects: @users))
        end
      end
    end

    private

    def render_admin_table
      style { ".permissions td { padding: 3px 5px 3px 5px }" }
      paginated_results do
        table(align: "center",
              class: "table table-striped permissions",
              cellspacing: "2") do
          thead { render_admin_header }
          tbody { render_admin_rows }
        end
      end
    end

    def render_admin_header
      tr do
        [:users_by_name_verified, :users_by_name_groups,
         :users_by_name_last_login, :users_by_name_id,
         :users_by_name_login, :users_by_name_name,
         :users_by_name_theme].each { |key| th { trusted_html(key.t) } }
        th { "#{:users_by_name_created_at.l} (#{@users.length})" }
      end
    end

    def render_admin_rows
      tr(height: "2")
      @users.each { |usr| render_admin_row(usr) }
    end

    def render_admin_row(usr)
      tr { admin_row_cells(usr) }
    end

    def admin_row_cells(usr)
      admin_meta_cells(usr)
      td { render(::Components::UserLink.new(user: usr, name: usr.login)) }
      admin_profile_cells(usr)
    end

    def admin_meta_cells(usr)
      td { plain(usr.verified.to_s) }
      td { plain(usr.user_groups.map(&:name).join(",")) }
      admin_meta_id_cells(usr)
    end

    def admin_meta_id_cells(usr)
      td { plain(safe_web_time(usr.last_login)) }
      td { plain(usr.id.to_s) }
    end

    def admin_profile_cells(usr)
      td { plain(usr.name.to_s) }
      td { plain(usr.theme.to_s) }
      td { plain(safe_web_time(usr.created_at)) }
    end

    def safe_web_time(time)
      time&.web_time || "--"
    end
  end
end
