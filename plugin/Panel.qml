import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "rene.llm-server"

  property string serverState: "checking"
  property bool busy: false
  property string busyAction: ""
  property string lastError: ""
  property string actionOutput: ""
  property string actionError: ""
  readonly property string llmScript: Quickshell.env("HOME") + "/Projects/vox-workspace/local-llm/llm.sh"

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function runAction(action) {
    if (busy || ["start", "stop", "restart"].indexOf(action) < 0) return
    busy = true
    busyAction = action
    lastError = ""
    actionOutput = ""
    actionError = ""
    // Bash also reports missing/non-executable scripts through stderr + exit code.
    actionProc.command = ["/bin/bash", llmScript, action]
    actionProc.running = true
    launchCheck.restart()
  }

  function finishAction(exitCode) {
    if (!busy) return
    if (exitCode !== 0) {
      var detail = (actionError || actionOutput).trim()
      lastError = "Could not " + busyAction + " LLM server.\n"
          + (detail ? detail.slice(-1600) : "Control process failed to launch or exited unexpectedly.")
    }
    busy = false
    busyAction = ""
    // Any probe started before the action completed can have stale results.
    if (statusProc.running) refreshAfterStatus = true
    else refresh()
  }

  property bool refreshAfterStatus: false

  function handlePress(mouseButton) {
    if (mouseButton === Qt.LeftButton) {
      if (serverState === "checking" || serverState === "unknown") {
        refresh()
        return
      }
      runAction(serverState === "running" || serverState === "unresponsive" ? "restart" : "start")
    } else if (mouseButton === Qt.RightButton) {
      runAction("stop")
    }
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "rene.llm-server"
    function refresh(): void { root.broadcast("refresh") }
    function status(): string {
      return JSON.stringify({state: root.serverState, busy: root.busy, error: root.lastError})
    }
    // Same path as pointer clicks, also useful for keyboard bindings and checks.
    function click(button: string): void {
      if (button === "left") root.handlePress(Qt.LeftButton)
      else if (button === "right") root.handlePress(Qt.RightButton)
    }
  }

  Process {
    id: statusProc
    command: ["/bin/bash", root.llmScript, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var result = JSON.parse(text)
          if (["running", "starting", "stopped", "unresponsive", "unmanaged"].indexOf(result.state) < 0)
            throw new Error("Invalid server status")
          root.serverState = result.state
        } catch (error) {
          root.serverState = "unknown"
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.serverState = "unknown"
      if (root.refreshAfterStatus) {
        root.refreshAfterStatus = false
        Qt.callLater(root.refresh)
      }
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.actionOutput = text
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.actionError = text
    }
    onExited: function(exitCode, exitStatus) {
      Qt.callLater(function() { root.finishAction(exitStatus === 0 ? exitCode : -1) })
    }
  }

  // QProcess may fail to spawn without emitting exited.
  Timer {
    id: launchCheck
    interval: 1500
    onTriggered: if (root.busy && !actionProc.running) root.finishAction(-1)
  }

  Timer {
    interval: root.busy || root.serverState === "starting" ? 1000 : 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.busy || root.serverState === "starting" ? "\uf1ce" : (root.lastError ? "\uf071" : "\uf542")
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    active: root.serverState === "running"
    activeColor: Color.accent
    useActiveColor: true
    tooltipText: {
      if (root.busy) return "LLM server: " + root.busyAction + " in progress… Waiting for completion."
      var hint = "Left-click: start/restart · Right-click: stop"
      if (root.lastError) return root.lastError + "\n" + hint
      if (root.serverState === "running") return "LLM server ready\nLeft-click: restart · Right-click: stop"
      if (root.serverState === "starting") return "LLM server is loading the model\n" + hint
      if (root.serverState === "unresponsive") return "LLM process exists but is not ready\n" + hint
      if (root.serverState === "unmanaged") return "Port 8080 is occupied by an unmanaged server.\nThis control cannot stop it."
      if (root.serverState === "stopped") return "LLM server stopped\nLeft-click: start · Right-click: stop"
      return "LLM server: status unavailable or checking…"
    }
    onPressed: function(mouseButton) { root.handlePress(mouseButton) }
  }
}
