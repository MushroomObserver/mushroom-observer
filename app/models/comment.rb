# Copyright (c) 2006 Nathan Wilson
# Licensed under the MIT License: http://www.opensource.org/licenses/mit-license.php

class Comment < ActiveRecord::Base

  belongs_to :observation

end
