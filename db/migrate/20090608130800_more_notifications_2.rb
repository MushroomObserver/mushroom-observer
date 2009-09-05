class MoreNotifications2 < ActiveRecord::Migration
  def self.up
    add_column :names,      "misspelling",         :boolean, :default => false, :null => false
    add_column :names,      "correct_spelling_id", :integer, :default => nil, :null => true
    add_column :past_names, "misspelling",         :boolean, :default => false, :null => false
    add_column :past_names, "correct_spelling_id", :integer, :default => nil, :null => true

    add_column :users, "email_comments_owner",         :boolean, :default => true, :null => false
    add_column :users, "email_comments_response",      :boolean, :default => true, :null => false
    add_column :users, "email_comments_all",           :boolean, :default => false, :null => false
    add_column :users, "email_observations_consensus", :boolean, :default => true, :null => false
    add_column :users, "email_observations_naming",    :boolean, :default => true, :null => false
    add_column :users, "email_observations_all",       :boolean, :default => false, :null => false
    add_column :users, "email_names_author",           :boolean, :default => true, :null => false
    add_column :users, "email_names_editor",           :boolean, :default => false, :null => false
    add_column :users, "email_names_reviewer",         :boolean, :default => true, :null => false
    add_column :users, "email_names_all",              :boolean, :default => false, :null => false
    add_column :users, "email_locations_author",       :boolean, :default => true, :null => false
    add_column :users, "email_locations_editor",       :boolean, :default => false, :null => false
    add_column :users, "email_locations_all",          :boolean, :default => false, :null => false
    add_column :users, "email_general_feature",        :boolean, :default => true, :null => false
    add_column :users, "email_general_commercial",     :boolean, :default => true, :null => false
    add_column :users, "email_general_question",       :boolean, :default => true, :null => false
    add_column :users, "email_digest",                 :enum, :limit => [:immediately, :daily, :weekly], :default => :immediately, :null => false
    add_column :users, "email_html",                   :boolean, :default => true, :null => false

    User.connection.update("update users set
      email_comments_owner         = comment_email,
      email_comments_response      = comment_response_email,
      email_comments_all           = false,
      email_observations_consensus = consensus_change_email,
      email_observations_naming    = name_proposal_email,
      email_observations_all       = false,
      email_names_author           = name_change_email,
      email_names_editor           = false,
      email_names_reviewer         = true,
      email_names_all              = false,
      email_locations_author       = name_change_email,
      email_locations_editor       = false,
      email_locations_all          = false,
      email_general_feature        = feature_email,
      email_general_commercial     = commercial_email,
      email_general_question       = question_email,
      email_digest                 = 'immediately',
      email_html                   = html_email")

    remove_column :users, "comment_email"
    remove_column :users, "comment_response_email"
    remove_column :users, "commercial_email"
    remove_column :users, "consensus_change_email"
    remove_column :users, "feature_email"
    remove_column :users, "html_email"
    remove_column :users, "name_change_email"
    remove_column :users, "name_proposal_email"
    remove_column :users, "question_email"

    create_table "authors_locations", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :id => false, :force => true do |t|
      t.column "location_id", :integer, :default => 0, :null => false
      t.column "user_id",     :integer, :default => 0, :null => false
    end

    create_table "editors_locations", :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :id => false, :force => true do |t|
      t.column "location_id", :integer, :default => 0, :null => false
      t.column "user_id",     :integer, :default => 0, :null => false
    end

    add_column :queued_emails, :flavor_tmp, :enum, :limit => QueuedEmail.all_flavors
    QueuedEmail.connection.update("update queued_emails set flavor_tmp=flavor")
    remove_column :queued_emails, :flavor

    add_column :queued_emails, :flavor, :enum, :limit => QueuedEmail.all_flavors
    QueuedEmail.connection.update("update queued_emails set flavor=flavor_tmp")
    remove_column :queued_emails, :flavor_tmp
  end

  def self.down
    remove_column :names,      "misspelling"
    remove_column :names,      "correct_spelling_id"
    remove_column :past_names, "misspelling"
    remove_column :past_names, "correct_spelling_id"

    add_column :users, "comment_email",          :boolean, :default => true, :null => false
    add_column :users, "comment_response_email", :boolean, :default => true, :null => false
    add_column :users, "commercial_email",       :boolean, :default => true, :null => false
    add_column :users, "consensus_change_email", :boolean, :default => true, :null => false
    add_column :users, "feature_email",          :boolean, :default => true, :null => false
    add_column :users, "html_email",             :boolean, :default => true, :null => false
    add_column :users, "name_change_email",      :boolean, :default => true, :null => false
    add_column :users, "name_proposal_email",    :boolean, :default => true, :null => false
    add_column :users, "question_email",         :boolean, :default => true, :null => false

    User.connection.update("update users set
      comment_email          = email_comments_owner,
      comment_response_email = email_comments_response,
      consensus_change_email = email_observations_consensus,
      name_proposal_email    = email_observations_naming,
      name_change_email      = email_names_author,
      feature_email          = email_general_feature,
      commercial_email       = email_general_commercial,
      question_email         = email_general_question,
      html_email             = email_html")

    remove_column :users, "email_comments_owner"
    remove_column :users, "email_comments_response"
    remove_column :users, "email_comments_all"
    remove_column :users, "email_observations_consensus"
    remove_column :users, "email_observations_naming"
    remove_column :users, "email_observations_all"
    remove_column :users, "email_names_author"
    remove_column :users, "email_names_editor"
    remove_column :users, "email_names_reviewer"
    remove_column :users, "email_names_all"
    remove_column :users, "email_locations_author"
    remove_column :users, "email_locations_editor"
    remove_column :users, "email_locations_all"
    remove_column :users, "email_general_feature"
    remove_column :users, "email_general_commercial"
    remove_column :users, "email_general_question"
    remove_column :users, "email_digest"
    remove_column :users, "email_html"

    drop_table "authors_locations"
    drop_table "editors_locations"
  end
end
