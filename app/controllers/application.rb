# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
require 'login_system'

CSS = ['Agaricus', 'Amanita', 'Cantharellaceae', 'Hygrocybe']

class ApplicationController < ActionController::Base
  include ExceptionNotifiable
  include LoginSystem
  
  before_filter(:disable_link_prefetching, :only => [
     # account_controller methods
    :logout_user, :delete,
    
    # observer_controller methods
    :destroy_observation, :destroy_image,
    :destroy_comment, :destroy_species_list])
  
  private
  
    def disable_link_prefetching
      if request.env["HTTP_X_MOZ"] == "prefetch" 
        logger.debug "prefetch detected: sending 403 Forbidden" 
        render_nothing "403 Forbidden" 
        return false
      end
    end
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

module ActiveRecord
    class Base
        def self.find_by_sql_with_limit(sql, offset, limit)
            sql = sanitize_sql(sql)
            add_limit!(sql, {:limit => limit, :offset => offset})
            find_by_sql(sql)
        end

        def self.count_by_sql_wrapping_select_query(sql)
            sql = sanitize_sql(sql)
            count_by_sql("select count(*) from (#{sql}) as my_table")
        end
   end
end

class ApplicationController < ActionController::Base
    def paginate_by_sql(model, sql, per_page, options={})
       if options[:count]
           if options[:count].is_a? Integer
               total = options[:count]
           else
               total = model.count_by_sql(options[:count])
           end
       else
           total = model.count_by_sql_wrapping_select_query(sql)
       end

       object_pages = Paginator.new self, total, per_page,
            @params['page']
       objects = model.find_by_sql_with_limit(sql,
            object_pages.current.to_sql[1], per_page)
       return [object_pages, objects]
   end
end
