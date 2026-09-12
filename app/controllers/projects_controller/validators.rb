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

  # A clean-but-unmatched name is accepted here (location stays nil) --
  # update_redirect_path sends the user to build it afterward, rather
  # than the old behavior of hard-blocking the whole edit until they
  # either fix the typo or give up on that name entirely.
  def valid_where
    where = params[:project][:place_name]
    @raw_place_name = where
    location = find_location(where)
    return false if @dubious_where_reasons.present?

    @project.location = location
    @project.save
  end

  def valid_dates
    return true unless ProjectConstraints.new(params).ends_before_start?

    flash_error(:add_project_ends_before_start.t)
    false
  end
end
