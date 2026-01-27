import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel, later } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class JitComposerWarningService extends Service {
  @service appEvents;
  @service composer;
  @service siteSettings;

  @tracked isAnalyzing = false;
  @tracked warningDismissed = false;
  @tracked lastResult = null;

  _debounceTimer = null;
  _abortController = null;
  _lastAnalyzedHash = null;
  _isMonitoring = false;

  willDestroy() {
    super.willDestroy(...arguments);
    this.stopMonitoring();
  }

  startMonitoring() {
    if (this._isMonitoring) {
      return;
    }
    this._isMonitoring = true;
    this.warningDismissed = false;
    this._lastAnalyzedHash = null;
    this.lastResult = null;
    this.appEvents.on("composer:typed-reply", this, this._onTypedReply);
  }

  stopMonitoring() {
    if (!this._isMonitoring) {
      return;
    }
    this._isMonitoring = false;
    this._cancelPendingAnalysis();
    this.appEvents.off("composer:typed-reply", this, this._onTypedReply);
  }

  @action
  dismissWarning() {
    this.warningDismissed = true;
    this.lastResult = null;
    this.appEvents.trigger("composer-messages:close");
  }

  _onTypedReply() {
    this._cancelPendingAnalysis();

    if (!this._shouldAnalyze()) {
      return;
    }

    const debounceMs =
      this.siteSettings.jit_composer_warning_debounce_seconds * 1000;
    this._debounceTimer = later(this, this._performAnalysis, debounceMs);
  }

  _shouldAnalyze() {
    if (this.warningDismissed) {
      return false;
    }

    if (!this.composer.model?.creatingTopic) {
      return false;
    }

    const content = this.composer.model?.reply || "";
    const minChars = this.siteSettings.jit_composer_warning_min_characters;

    if (content.length < minChars) {
      return false;
    }

    return true;
  }

  _cancelPendingAnalysis() {
    if (this._debounceTimer) {
      cancel(this._debounceTimer);
      this._debounceTimer = null;
    }

    if (this._abortController) {
      this._abortController.abort();
      this._abortController = null;
    }
  }

  async _performAnalysis() {
    const title = this.composer.model?.title || "";
    const content = this.composer.model?.reply || "";

    const contentHash = this._hashContent(title, content);
    if (contentHash === this._lastAnalyzedHash) {
      return;
    }

    this._abortController = new AbortController();
    this.isAnalyzing = true;

    try {
      const result = await ajax("/jit-composer-warning/analyze", {
        type: "POST",
        data: { title, content },
        signal: this._abortController.signal,
      });

      this._lastAnalyzedHash = contentHash;
      this.isAnalyzing = false;
      this._abortController = null;

      if (result.skip) {
        return;
      }

      if (result.analyzed && this._shouldShowWarning(result)) {
        this.lastResult = result;
        this._showWarning(result);
      }
    } catch (error) {
      this.isAnalyzing = false;
      this._abortController = null;

      if (error.name !== "AbortError") {
        // eslint-disable-next-line no-console
        console.error("JIT composer warning check failed:", error);
      }
    }
  }

  _shouldShowWarning(result) {
    // Check for common warning indicators in the response
    // The persona can define any fields, but we look for common patterns:
    // - show_warning: true (explicit)
    // - is_complete && !is_productive (productivity check)
    // - is_complete && is_unclear (clarity check)
    // - needs_improvement: true
    if (result.show_warning === true) {
      return true;
    }
    if (result.is_complete === true && result.is_productive === false) {
      return true;
    }
    if (result.is_complete === true && result.is_unclear === true) {
      return true;
    }
    if (result.needs_improvement === true) {
      return true;
    }
    return false;
  }

  _hashContent(title, content) {
    return `${title}::${content}`;
  }

  _showWarning(result) {
    this.appEvents.trigger("composer-messages:create", {
      templateName: "jit-composer-warning",
      extraClass: "jit-composer-warning",
      result,
    });
  }
}
