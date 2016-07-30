class Query::CommentAll < Query::Comment
#   def self.parameter_declarations
#     super.merge(
#     )
#   end
# 
#   def initialize
#   end
# 
#   def title
#     if by = params[:by]
#       by = :"sort_by_#{by}"
#       title_args[:tag] ||= :query_title_all_by
#       title_args[:order] = by.t
#     else
#       title_args[:tag] ||= :query_title_all
#     end
#   end
end
