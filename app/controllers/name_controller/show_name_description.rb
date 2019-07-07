# frozen_string_literal: true

# see app/controllers/name_controller.rb
class NameController
  before_action :login_required, except: [
    :show_name_description
  ]

  before_action :disable_link_prefetching, except: [
    :show_name_description
  ]

  def show_name_description
    store_location
    pass_query_params
    @description = find_or_goto_index(NameDescription, params[:id].to_s)
    return unless @description

    @name = @description.name
    return unless description_name_exists?
    return unless user_has_permission_to_see_description?

    update_view_stats(@description)
    @canonical_url = description_canonical_url
    @projects = users_projects_which_dont_have_desc_of_this_name
  end

  # ----------------------------------------------------------------------------

  protected

  def description_name_exists?
    return true if @name

    flash_error(:runtime_name_for_description_not_found.t)
    redirect_to(action: "list_names")
    false
  end

  def user_has_permission_to_see_description?
    return true if in_admin_mode? || @description.is_reader?(@user)

    if @description.source_type == :project
      flash_error(:runtime_show_draft_denied.t)
    else
      flash_error(:runtime_show_description_denied.t)
    end
    redirect_to_name_or_project
  end

  def redirect_to_name_or_project
    if @description.project
      redirect_to(controller: "project",
                  action:     "show_project",
                  id:         @description.project_id)
    else
      redirect_to(action: "show_name", id: @description.name_id)
    end
  end

  def description_canonical_url
    "#{MO.http_domain}/name/show_name_description/#{@description.id}"
  end

  def users_projects_which_dont_have_desc_of_this_name
    return [] unless @user

    @user.projects_member.select do |project|
      @name.descriptions.none? { |d| d.belongs_to_project?(project) }
    end
  end
end
