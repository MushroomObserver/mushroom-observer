class License < ActiveRecord::Base
  has_many :images
  has_many :users

  def self.current_names_and_ids(current_license=nil)
    result = License.find(:all, :conditions => "deprecated = 0").map{|l| [l.display_name, l.id]}
    if current_license
      if current_license.deprecated
        result.push([current_license.display_name, current_license.id])
      end
    end
    result
  end
  
end
