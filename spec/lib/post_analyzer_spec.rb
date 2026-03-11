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
  end
end
