class PopulateNameObeservationsCount < ActiveRecord::Migration[6.1]
  def change
    Name.find_each do |name|
      Name.reset_counters(name.id, :observations)
    end
  end
end
