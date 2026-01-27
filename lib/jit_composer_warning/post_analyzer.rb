# frozen_string_literal: true

module JitComposerWarning
  class PostAnalyzer
    def initialize(title:, content:, user:)
      @title = title
      @content = content
      @user = user
    end

    def analyze
      return { skip: true, reason: "ai_not_configured" } unless ai_available?
      return { skip: true, reason: "persona_not_configured" } unless persona_configured?
      return { skip: true, reason: "persona_invalid" } unless ai_persona

      persona = ai_persona.class_instance&.new
      return { skip: true, reason: "persona_invalid" } unless persona

      bot = DiscourseAi::Personas::Bot.as(@user, persona: persona, model: llm_model)
      ctx = build_bot_context

      structured_output = nil
      bot.reply(ctx) do |partial, _, type|
        structured_output = partial if type == :structured_output
      end

      parse_structured_output(structured_output)
    rescue => e
      Rails.logger.error(
        "JitComposerWarning::PostAnalyzer error: #{e.message}\n#{e.backtrace.join("\n")}",
      )
      { skip: true, reason: "error" }
    end

    private

    def ai_available?
      defined?(DiscourseAi) && defined?(DiscourseAi::Personas::Bot)
    end

    def persona_configured?
      SiteSetting.jit_composer_warning_persona.present?
    end

    def ai_persona
      @ai_persona ||= AiPersona.find_by(id: SiteSetting.jit_composer_warning_persona)
    end

    def llm_model
      ai_persona&.default_llm_id.present? ? LlmModel.find_by(id: ai_persona.default_llm_id) : nil
    end

    def build_bot_context
      content = +"Topic Draft Analysis\n\n"
      content << "Title: #{@title}\n\n" if @title.present?
      content << "Content:\n#{@content}"

      DiscourseAi::Personas::BotContext.new(
        user: @user,
        skip_show_thinking: true,
        feature_name: "jit_composer_warning",
        messages: [{ type: :user, content: content }],
      )
    end

    def parse_structured_output(structured_output)
      return { skip: true, reason: "no_response" } if structured_output.blank?

      response_format = ai_persona&.response_format || []
      result = { analyzed: true }

      response_format.each do |field|
        key = field["key"]
        result[key.to_sym] = structured_output.read_buffered_property(key.to_sym)
      end

      result
    end
  end
end
