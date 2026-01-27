import { withPluginApi } from "discourse/lib/plugin-api";
import JitComposerWarningComponent from "../components/composer-messages/jit-composer-warning";

export default {
  name: "jit-composer-warning",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");

    if (!currentUser?.can_use_jit_composer_warning) {
      return;
    }

    withPluginApi((api) => {
      api.registerValueTransformer(
        "composer-message-components",
        ({ value: components }) => {
          components["jit-composer-warning"] = JitComposerWarningComponent;
          return components;
        }
      );

      const appEvents = api.container.lookup("service:app-events");
      const jitComposerWarning = api.container.lookup(
        "service:jit-composer-warning"
      );

      appEvents.on("composer:opened", () => {
        const composer = api.container.lookup("service:composer");
        if (composer.model?.creatingTopic) {
          jitComposerWarning.startMonitoring();
        }
      });

      appEvents.on("composer:closed", () => {
        jitComposerWarning.stopMonitoring();
      });

      appEvents.on("composer:cancelled", () => {
        jitComposerWarning.stopMonitoring();
      });

      appEvents.on("composer:created-post", () => {
        jitComposerWarning.stopMonitoring();
      });
    });
  },
};
