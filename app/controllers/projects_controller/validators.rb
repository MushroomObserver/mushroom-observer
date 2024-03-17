# frozen_string_literal: true

module ProjectsController::Validators
  private

  def valid_title
    @title = params[:project][:title].to_s
    if @title.blank?
      flash_error(:add_project_need_title.t)
      false
    elsif (project2 = Project.find_by_title(@title)) &&
          (project2 != @project)
      flash_error(:add_project_already_exists.t(title: @title))
      false
    else
      true
    end
  end

  def valid_where
    where = params[:project][:place_name]
    location = find_location(where)
    return false if !location && where != ""

    @project.location = location
    @project.save
  end

  def valid_dates
    return true unless ProjectConstraints.new(params).ends_before_start?

    flash_error(:add_project_ends_before_start.t)
    false
  end
end
