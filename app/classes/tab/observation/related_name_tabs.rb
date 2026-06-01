# frozen_string_literal: true

# Action-nav links shown on an observation's name panel — points
# at the name itself plus three "observations matching this name's
# related taxa" filtered indexes. Replaces
# `Tabs::ObservationsHelper#obs_related_name_tabs`.
class Tab::Observation::RelatedNameTabs < Tab::Collection
  def initialize(user:, name:)
    super()
    @user = user
    @name = name
  end

  private

  def tabs
    [
      Tab::Object::Show.new(
        object: @name,
        title: :show_name.t(name: @name.display_name_brief_authors(@user))
      ),
      Tab::Observation::OfName.new(name: @name),
      Tab::Observation::OfLookAlikes.new(name: @name),
      Tab::Observation::OfRelatedTaxa.new(name: @name)
    ]
  end
end
