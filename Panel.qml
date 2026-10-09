import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string pluginId: "io.github.signaldirective.make-it-real"
  readonly property string home: Quickshell.env("HOME")
  readonly property string stateDirectory: home + "/.local/state/omarchy/make-it-real"
  readonly property string statePath: stateDirectory + "/welcome-seen"
  readonly property string starterPrompt: "I'm new to Omarchy. Show me how to change my wallpaper using the built-in controls. Give me the exact menu path and keyboard shortcut. Explain what each step does. Don't change anything."

  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool firstRunChecked: false
  property bool markerWriteStarted: false
  property bool copyingLesson: false
  property bool openTerminalAfterCopy: false
  property string statusText: ""
  property string promptDraft: ""

  function open(payloadJson) {
    opened = true
    surface.visible = true
  }

  function close() {
    if (opened || surface.visible) markWelcomeSeen()
    closingFromShell = true
    opened = false
    surface.visible = false
    closingFromShell = false
  }

  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  function resolveFirstRun(raw) {
    if (firstRunChecked) return
    firstRunChecked = true
    if (String(raw || "").trim() !== "seen") firstRunTimer.restart()
  }

  function markWelcomeSeen() {
    if (markerWriteStarted) return
    markerWriteStarted = true
    ensureStateDirectory.running = true
  }

  function showPromptFallback() {
    promptDraft = starterPrompt
    statusText = "Clipboard is unavailable. Select the example below and copy it manually."
  }

  function startLesson(openTerminal) {
    if (copyingLesson) return
    promptDraft = starterPrompt
    openTerminalAfterCopy = openTerminal === true
    statusText = "Copying the example question…"
    copyingLesson = true
    clipboardWriter.stdinEnabled = true
    clipboardWriter.running = true
  }

  function handleClipboardResult(exitCode) {
    copyingLesson = false
    if (exitCode !== 0) {
      showPromptFallback()
      return
    }
    statusText = openTerminalAfterCopy
      ? "Example copied. The terminal is opening; type opencode, then paste and send the question."
      : "Example copied. Open a terminal with Super + Return, type opencode, then paste and send the question."
    markWelcomeSeen()
    if (openTerminalAfterCopy) {
      requestClose()
      terminalTimer.start()
    }
  }

  function handleWindowClose() {
    if (!opened) return
    opened = false
    markWelcomeSeen()
    if (!closingFromShell && shell && typeof shell.hide === "function")
      shell.hide(pluginId)
  }

  function openMenu() {
    Quickshell.execDetached(["omarchy", "menu"])
  }

  function openThemePicker() {
    Quickshell.execDetached(["omarchy", "theme", "switcher"])
  }

  function openTerminalAfterManualCopy() {
    markWelcomeSeen()
    requestClose()
    terminalTimer.start()
  }

  property bool closingFromShell: false

  FileView {
    id: welcomeState
    path: root.statePath
    watchChanges: false
    printErrors: false
    onLoaded: root.resolveFirstRun(text())
    onLoadFailed: root.resolveFirstRun("")
  }

  Timer {
    id: firstRunTimer
    interval: 900
    repeat: false
    onTriggered: {
      if (root.shell && typeof root.shell.summon === "function")
        root.shell.summon(root.pluginId, "{}")
      else
        root.open("{}")
    }
  }

  Timer {
    id: terminalTimer
    interval: 350
    repeat: false
    onTriggered: Quickshell.execDetached(["omarchy", "launch", "terminal"])
  }

  Process {
    id: ensureStateDirectory
    command: ["mkdir", "-p", root.stateDirectory]
    onExited: function(exitCode) {
      if (exitCode === 0) writeWelcomeMarker.running = true
    }
  }

  Process {
    id: writeWelcomeMarker
    command: ["touch", root.statePath]
  }

  // Keep the user’s prompt out of the process list: wl-copy receives it on stdin.
  Process {
    id: clipboardWriter
    command: ["wl-copy"]
    stdinEnabled: true
    onStarted: {
      write(root.starterPrompt)
      stdinEnabled = false
    }
    onExited: function(exitCode) { root.handleClipboardResult(exitCode) }
  }

  FloatingWindow {
    id: surface
    title: "Make It Real — Omarchy"
    visible: false
    color: Color.background
    implicitWidth: 940
    implicitHeight: 790
    minimumSize: Qt.size(700, 620)

    onVisibleChanged: {
      if (visible) root.opened = true
      else root.handleWindowClose()
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.space(28)
      spacing: Style.space(18)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(10)

        Rectangle {
          Layout.preferredWidth: Style.space(34)
          Layout.preferredHeight: Style.space(34)
          radius: Style.cornerRadius
          color: Color.accent

          Text {
            anchors.centerIn: parent
            text: "M"
            color: Color.background
            font.family: Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            text: "MAKE IT REAL"
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            font.letterSpacing: 1.5
          }

          Text {
            text: "YOUR FIRST AGENT SESSION  /  001"
            color: Qt.darker(Color.foreground, 1.55)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }
        }

        Button {
          text: "Close"
          iconText: "×"
          focusable: true
          onClicked: root.requestClose()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: Math.max(1, Style.normalBorderWidth)
        color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
      }

      Flickable {
        id: scroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ColumnLayout {
          id: content
          width: scroll.width
          spacing: Style.space(18)

          Text {
            text: "NO JARGON. THREE MOVES. A REAL ANSWER."
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.7
          }

          Text {
            Layout.fillWidth: true
            text: "Your agent lives in the terminal."
            color: Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
            wrapMode: Text.WordWrap
          }

          Text {
            Layout.fillWidth: true
            text: "Open a terminal, start OpenCode, and ask for something in plain English. It can explain Omarchy, help change it, or help build what is missing."
            color: Qt.darker(Color.foreground, 1.35)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(10)

            BorderSurface {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(112)
              radius: Style.cornerRadius
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.035)
              borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.normalBorderWidth))

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(6)

                Text { text: "01  /  OPEN"; color: Color.cyan; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                Text { text: "Super + Return"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
                Text { text: "That opens your terminal."; color: Qt.darker(Color.foreground, 1.45); font.family: Style.font.family; font.pixelSize: Style.font.caption }
              }
            }

            BorderSurface {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(112)
              radius: Style.cornerRadius
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.035)
              borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.normalBorderWidth))

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(6)

                Text { text: "02  /  RUN"; color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                Text { text: "opencode"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true }
                Text { text: "Type it. Press Enter. OpenCode starts."; color: Qt.darker(Color.foreground, 1.45); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              }
            }

            BorderSurface {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(112)
              radius: Style.cornerRadius
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.035)
              borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.normalBorderWidth))

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(6)

                Text { text: "03  /  ASK"; color: Color.yellow; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
                Text { text: "Outcome + context"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle; font.bold: true; wrapMode: Text.WordWrap }
                Text { text: "Say what you want, what you know, and what not to change."; color: Qt.darker(Color.foreground, 1.45); font.family: Style.font.family; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap }
              }
            }
          }

          BorderSurface {
            Layout.fillWidth: true
            implicitHeight: promptColumn.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.055)
            borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.normalBorderWidth))

            Column {
              id: promptColumn
              anchors.fill: parent
              anchors.margins: Style.space(14)
              spacing: Style.space(8)

              RowLayout {
                width: parent.width
                Text {
                  Layout.fillWidth: true
                  text: "TRY A SAFE FIRST QUESTION"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }
                Button {
                  text: root.copyingLesson ? "Copying…" : "Copy question"
                  focusable: true
                  enabled: !root.copyingLesson
                  onClicked: root.startLesson(false)
                }
              }

              Text {
                width: parent.width
                text: root.starterPrompt
                textFormat: Text.PlainText
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              Text {
                width: parent.width
                text: "This asks OpenCode to find the real menu path and shortcut without changing anything. After that, try your own question."
                color: Qt.darker(Color.foreground, 1.4)
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }
          }

          BorderSurface {
            Layout.fillWidth: true
            implicitHeight: createColumn.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.035)
            borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.normalBorderWidth))

            Column {
              id: createColumn
              anchors.fill: parent
              anchors.margins: Style.space(14)
              spacing: Style.space(6)

              Text {
                text: "WHEN YOU WANT TO MAKE SOMETHING"
                color: Color.yellow
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }
              Text {
                width: parent.width
                text: "“I want [result]. First check if Omarchy already supports it. Show me the plan and files you'd change. Wait for my approval before editing.”"
                color: Color.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(10)

            Button {
              text: "Explore the Omarchy menu"
              focusable: true
              onClicked: root.openMenu()
            }
            Button {
              text: "Try the theme picker"
              focusable: true
              onClicked: root.openThemePicker()
            }
          }

          Text {
            Layout.fillWidth: true
            visible: root.statusText !== ""
            text: root.statusText
            color: Color.accent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          QQC.TextArea {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(150)
            visible: root.promptDraft !== "" && root.statusText.indexOf("Clipboard copy failed") === 0
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            text: root.promptDraft
            color: Color.foreground
            selectionColor: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
            background: BorderSurface {
              color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.04)
              borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.normalBorderWidth))
            }
          }

          Button {
            visible: root.promptDraft !== "" && root.statusText.indexOf("Clipboard copy failed") === 0
            text: "I copied it — open terminal"
            focusable: true
            onClicked: root.openTerminalAfterManualCopy()
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(12)

        Text {
          Layout.fillWidth: true
          text: "Copying the question does not send it or launch OpenCode. You choose when to start."
          color: Qt.darker(Color.foreground, 1.55)
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Button {
          text: "Copy question + open terminal"
          iconText: "↗"
          accent: Color.accent
          foreground: Color.foreground
          focusable: true
          enabled: !root.copyingLesson
          onClicked: root.startLesson(true)
        }
      }
    }
  }
}
