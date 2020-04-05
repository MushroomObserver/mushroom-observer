class FixCurators < ActiveRecord::Migration[4.2]
  def self.up
    # for h in Herbarium.find(:all) # Rails 3
    for h in Herbarium.all
      if h.curators == []
        user = User.where(email: h.email)[0]
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
