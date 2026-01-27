import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class JitComposerWarning extends Component {
  @service jitComposerWarning;

  <template>
    <ComposerTipCloseButton @action={{fn @closeMessage @message}} />

    <div class="composer-popup__content jit-composer-warning__content">
      <h3>{{i18n "jit_composer_warning.title"}}</h3>

      <p class="jit-composer-warning__body">
        {{#if @message.result.reason}}
          {{@message.result.reason}}
        {{else}}
          {{i18n "jit_composer_warning.default_message"}}
        {{/if}}
      </p>

      <div class="jit-composer-warning__actions">
        <DButton
          @action={{this.jitComposerWarning.dismissWarning}}
          @label="jit_composer_warning.dismiss"
          class="btn-primary jit-composer-warning__dismiss"
        />
      </div>
    </div>
  </template>
}
