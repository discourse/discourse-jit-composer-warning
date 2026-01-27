# frozen_string_literal: true

module JitComposerWarning
  class AnalyzeController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action :ensure_feature_enabled
    before_action :rate_limit_check

    def analyze
      params.require(:content)

      result =
        PostAnalyzer.new(
          title: params[:title] || "",
          content: params[:content],
          user: current_user,
        ).analyze

      render json: result
    end

    private

    def ensure_feature_enabled
      raise Discourse::InvalidAccess unless feature_enabled_for_user?
    end

    def feature_enabled_for_user?
      return false unless SiteSetting.jit_composer_warning_enabled
      return false if SiteSetting.jit_composer_warning_allowed_groups.blank?
      current_user.in_any_groups?(SiteSetting.jit_composer_warning_allowed_groups_map)
    end

    def rate_limit_check
      RateLimiter.new(
        current_user,
        "jit_composer_warning",
        SiteSetting.jit_composer_warning_rate_limit_per_minute,
        1.minute,
      ).performed!
    end
  end
end
