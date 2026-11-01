# frozen_string_literal: true

# Projects the given user belongs to -- used for "create a draft for
# project" UI, where only projects the user can submit content to
# are meaningful choices. Unlike Autocomplete::ForProject (every
# project, used where membership doesn't matter, e.g. tagging a
# field slip with any project for tracking), this filters to
# params[:user_id] (always sent by AutocompletersController#new via
# add_context_params).
class Autocomplete::ForUserProject < Autocomplete::ForProject
  attr_accessor :user_id

  def initialize(params = {})
    super
    self.user_id = params[:user_id]
  end

  def rough_matches(letter)
    super.select { |match| member_project_ids.include?(match[:id]) }
  end

  def exact_match(string)
    super.select { |match| member_project_ids.include?(match[:id]) }
  end

  private

  def member_project_ids
    @member_project_ids ||= user&.projects_member&.map(&:id) || []
  end

  def user
    @user ||= ::User.safe_find(user_id)
  end
end
