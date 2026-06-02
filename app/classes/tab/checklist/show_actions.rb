# frozen_string_literal: true

# Action-nav for the checklist show page. Three variants depending
# on what the checklist is scoped to:
#
# - user scope → user profile / observations / email question
# - species_list scope → show the list (+ edit when permitted)
# - site-wide (no user, no list) → contributors + site stats
#
# Caller passes `permission:` for the list-scope case to indicate
# whether the viewer can edit (per the existing `permission?(list)`
# helper).
class Tab::Checklist::ShowActions < Tab::Collection
  def initialize(user: nil, list: nil, permission: false)
    super()
    @user = user
    @list = list
    @permission = permission
  end

  private

  def tabs
    return for_user_tabs if @user
    return for_species_list_tabs if @list

    for_site_tabs
  end

  def for_user_tabs
    [Tab::User::Profile.new(user: @user),
     Tab::User::Observations.new(user: @user),
     Tab::User::EmailQuestion.new(user: @user)]
  end

  def for_species_list_tabs
    base = [Tab::Object::Show.new(object: @list)]
    return base unless @permission

    base + [Tab::SpeciesList::Edit.new(list: @list)]
  end

  def for_site_tabs
    [Tab::Contributor::Index.new,
     Tab::Info::SiteStats.new]
  end
end
