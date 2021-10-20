# module Types
module Inputs
  class UpdateUserInput < Inputs::BaseInputObject
    description "arguments necessary for editing a user profile. should be the whole form serialized."
    # the name is usually inferred by class name but can be overwritten
    graphql_name "UpdateUserInput"

    argument :login, String, required: false
    argument :name, String, required: false
    argument :email, String, required: false
    argument :password, String, required: true
    argument :admin, Boolean, required: false
    argument :alert, String, required: false
    argument :auth_code, String, required: false
    argument :mailing_address, String, required: false
    argument :notes, String, required: false
    argument :notes_template, String, required: false
    argument :theme, String, required: false
    argument :thumbnail_size, Integer, required: false
    argument :image_size, Integer, required: false
    argument :default_rss_type, String, required: false
    argument :location_format, Integer, required: false
    argument :hide_authors, Integer, required: true
    argument :thumbnail_maps, Boolean, required: true
    argument :keep_filenames, Integer, required: true
    argument :layout_count, Integer, required: false
    argument :view_owner_id, Boolean, required: true
    argument :content_filter, String, required: false
    argument :license_id, Integer, required: true
    argument :image_id, Integer, required: false
    argument :location_id, Integer, required: false
    argument :locale, String, required: false
    argument :votes_anonymous, Integer, required: false
    argument :bonuses, String, required: false
    argument :contribution, Integer, required: false
    argument :email_comments_owner, Boolean, required: true
    argument :email_comments_response, Boolean, required: true
    argument :email_comments_all, Boolean, required: true
    argument :email_observations_consensus, Boolean, required: true
    argument :email_observations_naming, Boolean, required: true
    argument :email_observations_all, Boolean, required: true
    argument :email_names_author, Boolean, required: true
    argument :email_names_editor, Boolean, required: true
    argument :email_names_reviewer, Boolean, required: true
    argument :email_names_all, Boolean, required: true
    argument :email_locations_author, Boolean, required: true
    argument :email_locations_editor, Boolean, required: true
    argument :email_locations_all, Boolean, required: true
    argument :email_general_feature, Boolean, required: true
    argument :email_general_commercial, Boolean, required: true
    argument :email_general_question, Boolean, required: true
    argument :email_html, Boolean, required: true
    argument :email_locations_admin, Boolean, required: false
    argument :email_names_admin, Boolean, required: false
  end
end
# end
