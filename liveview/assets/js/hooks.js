let Hooks = {};

Hooks.PreviewKeyboardNavigation = {
  mounted() {
    // Add a keydown event listener to the window
    this.handleKeydown = (event) => {
      if (event.key === "ArrowLeft") {
        this.pushEvent("previewNavigate", { direction: "left" });
      } else if (event.key === "ArrowRight") {
        this.pushEvent("previewNavigate", { direction: "right" });
      } else if (event.key === "Escape") {
        this.pushEvent("hide-preview", {});
      }
    };

    window.addEventListener("keydown", this.handleKeydown);
  },

  destroyed() {
    // Clean up the event listener when the hook is destroyed
    window.removeEventListener("keydown", this.handleKeydown);
  },
};

export default Hooks;
