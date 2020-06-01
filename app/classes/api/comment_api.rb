# frozen_string_literal: true

class API
  # API for Comment
  class CommentAPI < ModelAPI
    self.model = Comment

    self.high_detail_page_length = 100
    self.low_detail_page_length  = 1000
    self.put_page_length         = 1000
    self.delete_page_length      = 1000

    self.high_detail_includes = [
      :target,
      :user
    ]

    def query_params
      @target = parse(:object, :target, limit: Comment.all_types, help: 1)
      {
        where: sql_id_condition,
        created_at: parse_range(:time, :created_at),
        updated_at: parse_range(:time, :updated_at),
        users: parse_array(:user, :user, help: :creator),
        types: parse_array(:enum, :type, limit: Comment.all_type_tags),
        summary_has: parse(:string, :summary_has, help: 1),
        content_has: parse(:string, :content_has, help: 1),
        target: @target ? @target.id : nil,
        type: @target ? @target.class.name : nil
      }
    end

    def create_params
      {
        target: parse(:object, :target, limit: Comment.all_types),
        summary: parse(:string, :summary, limit: 100),
        comment: parse(:string, :content),
        user: @user
      }
    end

    def update_params
      {
        summary: parse(:string, :set_summary, limit: 100, not_blank: true),
        comment: parse(:string, :set_content)
      }
    end

    def query_flavor
      @target ? :for_target : :all
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
  end
end
