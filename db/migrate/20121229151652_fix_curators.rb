class FixCurators < ActiveRecord::Migration
  def self.up
    for h in Herbarium.find(:all)
      if h.curators == []
        user = User.find_all_by_email(h.email)[0]
        if user
          h.curators.push(user)
          h.save
        else
          print "Unable to find a user with the email address #{h.email}\n"
        end
      end
    end
  end

  def self.down
  end
end
