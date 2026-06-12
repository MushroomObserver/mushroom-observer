# frozen_string_literal: true

# Action-nav tabs for the species_list show page — rendered as the
# right-side context-nav dropdown via `add_context_nav`. Always
# includes the "logged in" tabs (download / set source / clone /
# write_in / add-remove-from-another). When the viewing user can
# manage the list (owner or admin), the 5 "user" tabs are appended
# (add new observations / manage projects / edit / clear / destroy).
#
# Caller is responsible for computing `can_manage` — typically by
# calling `permission?(@species_list)` in the Phlex view. Tab POROs
# stay request-agnostic; the caller has the authentication context.
class Tab::SpeciesList::Show < Tab::Collection
  def initialize(list:, can_manage:, q_param: nil)
    super()
    @list = list
    @can_manage = can_manage
    @q_param = q_param
  end

  private

  def tabs
    base = logged_in_tabs
    return base unless @can_manage

    base + user_tabs
  end

  def logged_in_tabs
    [
      Tab::SpeciesList::Download.new(list: @list, q_param: @q_param),
      Tab::SpeciesList::SetSource.new(list: @list, q_param: @q_param),
      Tab::SpeciesList::Clone.new(list: @list),
      Tab::SpeciesList::WriteIn.new(list: @list),
      Tab::SpeciesList::AddRemoveFromAnotherList.new(list: @list,
                                                     q_param: @q_param)
    ]
  end

  def user_tabs
    [
      Tab::SpeciesList::AddNewObservations.new(list: @list),
      Tab::SpeciesList::ManageProjects.new(list: @list),
      Tab::SpeciesList::Edit.new(list: @list),
      Tab::SpeciesList::Clear.new(list: @list),
      Tab::SpeciesList::Destroy.new(list: @list)
    ]
  end
end
