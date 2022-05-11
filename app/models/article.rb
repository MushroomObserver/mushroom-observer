# frozen_string_literal: true

# Article
# Simple model used for news about MO, e.g., new releases
# New articles are added to the Acitivity feed
#
# == Attributes
#
#  title::              headline
#  id::                 unique numerical id (starting at 1)
#  rss_log_id::         unique numerical id
#  created_at::         Date/time it was first created.
#  updated_at::         Date/time it was last updated.
#  user::               user who created article
#
# == methods
#  author::             user.name + user.login
#  can_edit?            Can the user create, edit, or delete Articles?
#  display_name::       name boldfaced
#  format_name          name
#  text_name            name without formatting
#  unique_format_name   name + id
#  unique_text_name     name + id without formatting
#
class Article < AbstractModel
  require "arel-helpers"
  include ArelHelpers::ArelTable

  belongs_to :user
  belongs_to :rss_log

  # Automatically log standard events.
  self.autolog_events = [:created!, :updated!, :destroyed!]

  # title boldfaced (in Textile). Used by show and index templates
  def display_title
    "**#{title}**"
  end

  # Article creator. Used by show and index templates
  def author
    "#{user.name} (#{user.login})"
  end

  # used by MatrixBoxPresenter to show orphaned obects
  def format_name
    title
  end

  # used by RSS feed
  def text_name
    title.to_s.t.html_to_ascii
  end

  # used by MatrixBoxPresenter to show unorphaned obects
  def unique_format_name
    title + " (#{id || "?"})"
  end

  # used by RSS feed
  def unique_text_name
    text_name + " (#{id || "?"})"
  end

  # wrapper around class method of same name
  def can_edit?(user)
    Article.can_edit?(user)
  end

  # Can the user create, edit, or delete Articles?
  def self.can_edit?(user)
    # To avoid throwing errors, deny permission if the Project which controls
    #   Article write permission does not yet exist or was deleted.
    return false unless news_articles_project

    news_articles_project.is_member?(user)
  end

  # Project used to administer Article write permission.
  # User of this project may create, edit, or delete Articles.
  def self.news_articles_project
    Project.find_by(title: "News Articles")
  end
end
