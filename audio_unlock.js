(function () {
  if (window.__aseanUnlockAudio) {
    return;
  }
  var Native = window.AudioContext || window.webkitAudioContext;
  if (Native) {
    var Wrapped = class extends Native {
      constructor() {
        super(...arguments);
        if (!window.__aseanAudio) {
          window.__aseanAudio = [];
        }
        window.__aseanAudio.push(this);
      }
    };
    window.AudioContext = Wrapped;
    if (window.webkitAudioContext) {
      window.webkitAudioContext = Wrapped;
    }
  }
  function drop() {
    window.removeEventListener("pointerdown", onGesture, true);
    window.removeEventListener("touchstart", onGesture, true);
    window.removeEventListener("keydown", onGesture, true);
  }
  function logState() {
    var list = window.__aseanAudio || [];
    var ctx = list.length ? list[list.length - 1] : null;
    var state = ctx ? ctx.state : "none";
    window.__aseanAudioState = state;
    console.log("audio context state: " + state);
    if (state === "running") {
      drop();
    }
    return state;
  }
  window.__aseanUnlockAudio = function () {
    var list = window.__aseanAudio || [];
    var jobs = [];
    for (var i = 0; i < list.length; i++) {
      var ctx = list[i];
      if (ctx && ctx.state !== "running" && ctx.resume) {
        try {
          jobs.push(ctx.resume());
        } catch (err) {
          console.log("audio resume failed");
        }
      }
    }
    var state = logState();
    if (jobs.length) {
      Promise.all(jobs).then(logState, logState);
    }
    return state;
  };
  function onGesture() {
    window.__aseanUnlockAudio();
  }
  window.addEventListener("pointerdown", onGesture, true);
  window.addEventListener("touchstart", onGesture, true);
  window.addEventListener("keydown", onGesture, true);
})();
