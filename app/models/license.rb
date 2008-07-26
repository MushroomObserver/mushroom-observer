#
#  Very simple model to hold info about a copyright license.  Intended for use
#  by Image, but I guess it could apply to anything including documents users
#  might upload to the site some day.  Each license:
#  
#  1. has a name
#  2. has a URL
#  3. can be deprecated
#  
#  Public Methods:
#    License.current_names_and_ids     Get list of non-deprecated licenses.
#
################################################################################

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
