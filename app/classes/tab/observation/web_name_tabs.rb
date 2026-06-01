# frozen_string_literal: true

# Cross-domain composer: external "web search for this name" links
# rendered in the observation name panel. Each entry is a name
# external Tab PORO (Mycoportal, MycobankSearch, UserGoogleImages).
# Replaces `Tabs::ObservationsHelper#user_observation_web_name_tabs`.
class Tab::Observation::WebNameTabs < Tab::Collection
  def initialize(user:, name:)
    super()
    @user = user
    @name = name
  end

  private

  def tabs
    [
      Tab::Name::Mycoportal.new(name: @name),
      Tab::Name::MycobankSearch.new(name: @name),
      Tab::Name::UserGoogleImages.new(user: @user, name: @name)
    ]
  end
end
