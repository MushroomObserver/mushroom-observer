# encoding: utf-8

class API
  class CommentAPI < ModelAPI
    self.model = Comment

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :target,
      :user,
    ]

    def query_params
      {
          where: sql_id_condition,
          created_at: parse_time_range(:created_at),
          updated_at: parse_time_range(:updated_at),
          users: parse_users(:user),
          types: parse_enum(:type, :limit => Comment.all_type_tags),
          summary_has: parse_string(:summary_has),
          content_has: parse_string(:content_has),
        # :targets     => parse_objects(:target, :limit => Comment.all_types),
      }
    end

    def create_params
      {
          summary: parse_string(:summary, :limit => 100),
          comment: parse_string(:content),
          target: parse_object(:target, :limit => Comment.all_types),
      }
    end

    def validate_create_params!(params)
      raise MissingParameter.new(:summary) if params[:summary].blank?
      raise MissingParameter.new(:content) if params[:comment].blank?
      raise MissingParameter.new(:target)  if params[:target].blank?
      must_have_view_permission!(params[:target])
    end

    def after_create(comment)
      comment.log_create
    end

    def update_params
      {
          summary: parse_string(:set_summary, :limit => 100),
          comment: parse_string(:set_content),
      }
    end
  end
end
