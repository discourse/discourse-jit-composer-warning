# frozen_string_literal: true

RSpec.describe JitComposerWarning::PostAnalyzer do
  fab!(:user)

  before { enable_current_plugin }

  let(:analyzer) { described_class.new(title: "Test Title", content: "Test content", user: user) }

  describe "#analyze" do
    context "when agent is not configured" do
      before { SiteSetting.jit_composer_warning_agent = "" }

      it "returns skip with agent_not_configured reason" do
        result = analyzer.analyze
        expect(result[:skip]).to eq(true)
        expect(result[:reason]).to eq("agent_not_configured")
      end
    end

    context "when agent is configured but not found in database" do
      before { SiteSetting.jit_composer_warning_agent = "999999" }

      it "returns skip with agent_invalid reason" do
        result = analyzer.analyze
        expect(result[:skip]).to eq(true)
        expect(result[:reason]).to eq("agent_invalid")
      end
    end

    context "when an error occurs during analysis" do
      fab!(:ai_agent)

      before { SiteSetting.jit_composer_warning_agent = ai_agent.id.to_s }

      it "returns skip with error reason and logs the error" do
        Rails.logger.expects(:error).with(regexp_matches(/JitComposerWarning::PostAnalyzer error/))
        result = analyzer.analyze
        expect(result[:skip]).to eq(true)
        expect(result[:reason]).to eq("error")
      end
    end

    context "when the bot returns structured output" do
      fab!(:ai_agent)

      before { SiteSetting.jit_composer_warning_agent = ai_agent.id.to_s }

      def stub_bot_with(properties)
        structured_output = instance_double(DiscourseAi::Completions::StructuredOutput)
        properties.each do |key, value|
          allow(structured_output).to receive(:read_buffered_property).with(key).and_return(value)
        end

        bot = instance_double(DiscourseAi::Agents::Bot)
        allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(bot)
        allow(bot).to receive(:reply).and_yield(structured_output, nil, :structured_output)
      end

      it "returns show_warning and message when the agent decides to warn" do
        stub_bot_with(
          show_warning: true,
          message: "Check our [help center](https://example.com/help).",
        )

        result = analyzer.analyze

        expect(result[:analyzed]).to eq(true)
        expect(result[:show_warning]).to eq(true)
        expect(result[:message]).to eq("Check our [help center](https://example.com/help).")
      end

      it "coerces show_warning to false when the agent does not warn" do
        stub_bot_with(show_warning: false, message: nil)

        result = analyzer.analyze

        expect(result[:analyzed]).to eq(true)
        expect(result[:show_warning]).to eq(false)
      end

      it "treats a missing show_warning value as false" do
        stub_bot_with(show_warning: nil, message: nil)

        result = analyzer.analyze

        expect(result[:show_warning]).to eq(false)
      end
    end

    context "when the bot yields no structured output" do
      fab!(:ai_agent)

      before { SiteSetting.jit_composer_warning_agent = ai_agent.id.to_s }

      it "returns skip with no_response reason" do
        bot = instance_double(DiscourseAi::Agents::Bot)
        allow(DiscourseAi::Agents::Bot).to receive(:as).and_return(bot)
        allow(bot).to receive(:reply)

        result = analyzer.analyze

        expect(result[:skip]).to eq(true)
        expect(result[:reason]).to eq("no_response")
      end
    end
  end
end
