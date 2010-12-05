class Donation < ActiveRecord::Base
  belongs_to :user

  def self.get_donor_list
    return connection.select_all("SELECT who, SUM(amount) total, MAX(created_at) most_recent FROM donations GROUP BY who, email ORDER BY total DESC, most_recent DESC")
  end

end
