namespace :cache do
  desc "Refresh all the caches"
  task :all => [
    :refresh_contributions,
    :refresh_votes
  ]

  desc "Recalculate user contributions"
  task(:refresh_contributions => :environment) do
    print "Refreshing user.contribution...\n"
    SiteData.new.get_all_user_data
  end

  desc "Recalculate vote caches for observations and namings"
  task(:refresh_votes => :environment) do
    print "Refreshing naming.vote_cache...\n"
    for n in Naming.find(:all)
      print "##{n.id}\r"
      n.calc_vote_table
    end
    print "Refreshing observation.vote_cache...\n"
    for o in Observation.find(:all)
      print "##{o.id}\r"
      o.calc_consensus
    end
    print "Done.    \n"
  end
  
  desc "Reset the queued_emails flavor enum"
  task(:refresh_queued_emails => :environment) do
    print "Refreshing flavor enum for queued_emails...\n"
    ActiveRecord::Migration.add_column :queued_emails, :flavor_tmp, :enum, :limit => QueuedEmail.all_flavors
    QueuedEmail.connection.update("update queued_emails set flavor_tmp=flavor+0")
    ActiveRecord::Migration.remove_column :queued_emails, :flavor
    ActiveRecord::Migration.add_column :queued_emails, :flavor, :enum, :limit => QueuedEmail.all_flavors
    QueuedEmail.connection.update("update queued_emails set flavor=flavor_tmp")
    ActiveRecord::Migration.remove_column :queued_emails, :flavor_tmp
  end
  
  desc "Reset the name review_status enum"
  task(:refresh_name_review_status => :environment) do
    print "Refreshing review_status enum for names and past_names...\n"
    ActiveRecord::Migration.add_column :names, :review_status_tmp, :enum, :limit => Name.all_review_statuses
    ActiveRecord::Migration.add_column :past_names, :review_status_tmp, :enum, :limit => Name.all_review_statuses
    Name.connection.update("update names set review_status_tmp=review_status+0")
    Name.connection.update("update past_names set review_status_tmp=review_status+0")
    ActiveRecord::Migration.remove_column :names, :review_status
    ActiveRecord::Migration.remove_column :past_names, :review_status
    ActiveRecord::Migration.add_column :names, :review_status, :enum, :limit => Name.all_review_statuses
    ActiveRecord::Migration.add_column :past_names, :review_status, :enum, :limit => Name.all_review_statuses
    Name.connection.update("update names set review_status=review_status_tmp")
    Name.connection.update("update past_names set review_status=review_status_tmp")
    ActiveRecord::Migration.remove_column :names, :review_status_tmp
    ActiveRecord::Migration.remove_column :past_names, :review_status_tmp
  end
  
  desc "Add reviewers"
  task(:add_reviewers => :environment) do
    group = UserGroup.find_by_name('reviewers')
    for login in [] # Should be a list of logins for users you want to add to reviewers list
      user = User.find_by_login(login)
      unless user.user_groups.member?(group)
        user.user_groups << group
        user.save
        print "Added #{login} to the reviewers group\n"
      else
        print "#{login} is already in the reviewers group\n"
      end
    end
  end
  
  desc "Update authors and editors"
  task(:update_authors => :environment) do
    Name.connection.update %(
      UPDATE names
      SET user_id = 1
      WHERE user_id = 0
    )

    Name.connection.update %(
      UPDATE past_names
      SET user_id = 1
      WHERE user_id = 0
    )

    users = {}
    for n in Name.find(:all)
      user_ids = []
      author_id = nil
      last_version = 0
      for v in n.versions
        if last_version > v.version
          print "Expected version numbers to be strictly increasing\n"
          print "#{n.search_name}: #{last_version} > #{v.version}\n"
        end
        last_version = v.version
        id = v.user_id
        users[id] = User.find(v.user_id) unless users.keys().member?(id)
        user_ids.push(id) unless user_ids.member?(id)
        unless v.gen_desc.nil? or v.gen_desc == '' or author_id
          author_id = v.user_id
        end
      end
      for id in user_ids
        n.editors.push(users[id])
      end
      if author_id
        n.authors.push(users[author_id])
      end
      n.save
    end
  end
  
end
