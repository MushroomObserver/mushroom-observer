class Query::ObservationAdvancedSearch < Query::Observation
  include Query::AdvancedSearch

  def initialize
    name, user, location, content = google_parse_params
    make_sure_user_entered_something(name, user, location, content)
    add_join(:names)      unless name.blank?
    add_join(:users)      unless user.blank?
    add_join(:locations!) unless location.blank?
    add_name_condition(name)
    add_user_condition(user)
    add_location_condition(location)
    add_content_condition(content)
  end

  def content_join_spec
    :comments
  end
end
