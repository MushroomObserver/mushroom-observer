# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'login_system'

CSS = ['Agaricus', 'Amanita', 'Cantharellaceae', 'Hygrocybe']

class ApplicationController < ActionController::Base
  include LoginSystem
  model :user
end

module Enumerable
  def select_rand
    tmp = self.to_a
    tmp[Kernel.rand(tmp.size)]
  end
end

def rand_char(str)
  sprintf("%c", str[Kernel.rand(str.length)])
end

def random_password(len)
  result = ''
  for n in (0..len)
    result += rand_char('abcdefghijklmnopqrstuvwxyz0123456789')
  end
  result
end
