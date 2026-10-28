(function () {
  if (window.__aseanUnlockAudio) {
    return;
  }
  window.__aseanAudio = window.__aseanAudio || [];
  var NativeCtx = window.AudioContext || window.webkitAudioContext;
  if (NativeCtx && !window.__aseanAudioWrapped) {
    window.__aseanAudioWrapped = true;
    var WrappedCtx = function (opts) {
      var ctx = new NativeCtx(opts);
      if (window.__aseanAudio.indexOf(ctx) < 0) {
        window.__aseanAudio.push(ctx);
      }
      if (window.__aseanGestured && ctx.resume && ctx.state !== "running") {
        ctx.resume();
      }
      return ctx;
    };
    WrappedCtx.prototype = NativeCtx.prototype;
    window.AudioContext = WrappedCtx;
    if (window.webkitAudioContext) {
      window.webkitAudioContext = WrappedCtx;
    }
  }
  function adopt() {
    var list = window.__aseanAudio;
    var ctx = window.GodotAudio && window.GodotAudio.ctx;
    if (ctx && list.indexOf(ctx) < 0) {
      list.push(ctx);
    }
    return list;
  }
  function remember(state) {
    if (window.__aseanAudioState !== state) {
      window.__aseanAudioState = state;
      console.log("audio context state: " + state);
    }
    return state;
  }
  function logState() {
    var list = adopt();
    var ctx = list.length ? list[list.length - 1] : null;
    return remember(ctx ? ctx.state : "none");
  }
  function resumeAll() {
    var list = adopt();
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
    return jobs;
  }
  window.__aseanGestured = false;
  window.__aseanUnlockAudio = function () {
    window.__aseanGestured = true;
    var jobs = resumeAll();
    var state = logState();
    if (jobs.length) {
      Promise.all(jobs).then(logState, logState);
    }
    return state;
  };
  window.__aseanAudioQuiet = function () {
    var list = adopt();
    var ctx = list.length ? list[list.length - 1] : null;
    return ctx ? ctx.state : "none";
  };
  function onGesture() {
    window.__aseanUnlockAudio();
  }
  window.addEventListener("pointerdown", onGesture, true);
  window.addEventListener("touchstart", onGesture, true);
  window.addEventListener("keydown", onGesture, true);
  window.setInterval(function () {
    if (window.__aseanGestured) {
      window.__aseanUnlockAudio();
    }
  }, 250);
})();
