import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.fullo.omarchy-bar-manager"
  ipcTarget: "io.github.fullo.omarchy-bar-manager"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // Config state
  property var currentConfig: null
  property var originalConfig: null
  property var diff: []
  property string errorText: ""
  property bool hasChanges: false
  property bool loaded: false

  // View state
  property int activeTab: 0
  property string editingPluginId: ""
  property string editingPluginSection: ""
  property var editingPluginSettings: ({})
  property string addTargetSection: "center"

  readonly property string home: Quickshell.env("HOME")
  readonly property string configDir: home + "/.config/omarchy"

  // Styling
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  FileView {
    id: shellFileView
    path: root.configDir + "/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var config = JSON.parse(text())
        root.currentConfig = JSON.parse(JSON.stringify(config))
        root.originalConfig = JSON.parse(JSON.stringify(config))
        root.errorText = ""
        root.loaded = true
        checkChanges()
      } catch(e) {
        root.errorText = "Failed to parse shell.json: " + e.message
        root.loaded = false
      }
    }
    onLoadFailed: {
      root.errorText = "Failed to read shell.json"
      root.loaded = false
    }
  }

  // Plugin registry from `omarchy plugin list --json`
  property var installedPlugins: []

  Process {
    id: pluginListProcess
    running: false
    command: ["omarchy", "plugin", "list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var plugins = JSON.parse(text)
          root.installedPlugins = plugins.filter(function(p) {
            return p.kinds && p.kinds.indexOf("bar-widget") >= 0 && p.enabled
          })
        } catch(e) {
          console.warn("bar-manager: Failed to parse plugin list:", e.message)
        }
      }
    }
  }

  function refreshPluginList() {
    pluginListProcess.running = true
  }

  function open() {
    root.controller.show()
    refreshPluginList()
    loadConfig()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() { root.opened ? root.close() : root.open() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function loadConfig() {
    shellFileView.reload()
  }

  function checkChanges() {
    if (!currentConfig || !originalConfig) { hasChanges = false; return }
    hasChanges = JSON.stringify(currentConfig) !== JSON.stringify(originalConfig)
    diff = Model.buildDiff(originalConfig, currentConfig)
  }

  function saveConfig() {
    if (!currentConfig) return
    var validation = Model.validateConfig(currentConfig)
    if (!validation.valid) {
      errorText = "Validation failed:\n" + validation.errors.join("\n")
      return
    }
    // Ask user confirmation
    // Write via shell.mutateShellConfig if available, else direct file write
    if (root.bar && root.bar.shell && typeof root.bar.shell.mutateShellConfig === "function") {
      var configCopy = JSON.parse(JSON.stringify(currentConfig))
      root.bar.shell.mutateShellConfig(function(config) {
        // Copy our changes into the shell's config
        for (var k in configCopy) config[k] = configCopy[k]
      })
      root.originalConfig = JSON.parse(JSON.stringify(currentConfig))
      hasChanges = false
      diff = []
      errorText = ""
    } else {
      errorText = "Cannot save — shell.mutateShellConfig not available"
    }
  }

  function togglePlugin(pluginId, section) {
    if (!currentConfig || !currentConfig.bar || !currentConfig.bar.layout) return
    var entries = currentConfig.bar.layout[section]
    if (!Array.isArray(entries)) return
    var idx = -1
    for (var i = 0; i < entries.length; i++) {
      if (Model.entryId(entries[i]) === pluginId) { idx = i; break }
    }
    if (idx >= 0) {
      entries.splice(idx, 1)
    } else {
      entries.push({ id: pluginId })
    }
    currentConfig = JSON.parse(JSON.stringify(currentConfig))
    checkChanges()
  }

  function movePlugin(pluginId, fromSection, toSection) {
    if (!currentConfig || !currentConfig.bar || !currentConfig.bar.layout) return
    var from = currentConfig.bar.layout[fromSection]
    var to = currentConfig.bar.layout[toSection]
    if (!Array.isArray(from) || !Array.isArray(to)) return
    var idx = -1
    for (var i = 0; i < from.length; i++) {
      if (Model.entryId(from[i]) === pluginId) { idx = i; break }
    }
    if (idx < 0) return
    var entry = from.splice(idx, 1)[0]
    to.push(entry)
    currentConfig = JSON.parse(JSON.stringify(currentConfig))
    checkChanges()
  }

  function reorderPlugin(pluginId, section, delta) {
    if (!currentConfig || !currentConfig.bar || !currentConfig.bar.layout) return
    var entries = currentConfig.bar.layout[section]
    if (!Array.isArray(entries)) return
    var idx = -1
    for (var i = 0; i < entries.length; i++) {
      if (Model.entryId(entries[i]) === pluginId) { idx = i; break }
    }
    if (idx < 0) return
    var newIdx = idx + delta
    if (newIdx < 0 || newIdx >= entries.length) return
    var temp = entries[idx]
    entries[idx] = entries[newIdx]
    entries[newIdx] = temp
    currentConfig = JSON.parse(JSON.stringify(currentConfig))
    checkChanges()
  }

  function addPlugin(pluginId, section) {
    if (!currentConfig || !currentConfig.bar || !currentConfig.bar.layout) return
    if (!currentConfig.bar.layout[section]) currentConfig.bar.layout[section] = []
    currentConfig.bar.layout[section].push({ id: pluginId })
    currentConfig = JSON.parse(JSON.stringify(currentConfig))
    checkChanges()
  }

  function removePlugin(pluginId, section) {
    if (!currentConfig || !currentConfig.bar || !currentConfig.bar.layout) return
    var entries = currentConfig.bar.layout[section]
    if (!Array.isArray(entries)) return
    for (var i = entries.length - 1; i >= 0; i--) {
      if (Model.entryId(entries[i]) === pluginId) { entries.splice(i, 1); break }
    }
    currentConfig = JSON.parse(JSON.stringify(currentConfig))
    checkChanges()
  }

  function setBarPosition(pos) {
    if (!currentConfig) return
    if (!currentConfig.bar) currentConfig.bar = {}
    currentConfig.bar.position = pos
    currentConfig = JSON.parse(JSON.stringify(currentConfig))
    checkChanges()
  }

  function installedPluginsList() {
    return root.installedPlugins.map(function(p) { return p.id })
  }

  function pluginsNotInLayout() {
    if (!currentConfig) return []
    var inLayout = Model.pluginsInLayout(currentConfig)
    var all = installedPluginsList()
    var result = []
    for (var i = 0; i < all.length; i++) {
      if (!inLayout[all[i]]) result.push(all[i])
    }
    return result
  }

  function sectionEntries(section) {
    if (!currentConfig || !currentConfig.bar || !currentConfig.bar.layout) return []
    var entries = currentConfig.bar.layout[section]
    return Array.isArray(entries) ? entries : []
  }

  function pluginSettings(pluginId, section) {
    var entries = sectionEntries(section)
    for (var i = 0; i < entries.length; i++) {
      if (Model.entryId(entries[i]) === pluginId) return Model.entrySettings(entries[i])
    }
    return {}
  }

  function updatePluginSettings(pluginId, section, key, value) {
    if (!currentConfig || !currentConfig.bar || !currentConfig.bar.layout) return
    var entries = currentConfig.bar.layout[section]
    if (!Array.isArray(entries)) return
    for (var i = 0; i < entries.length; i++) {
      if (Model.entryId(entries[i]) === pluginId) {
        if (typeof entries[i] === "string") entries[i] = { id: pluginId }
        entries[i][key] = value
        break
      }
    }
    currentConfig = JSON.parse(JSON.stringify(currentConfig))
    checkChanges()
  }

  function pluginDisplayName(pluginId) {
    for (var i = 0; i < root.installedPlugins.length; i++) {
      if (root.installedPlugins[i].id === pluginId) return root.installedPlugins[i].name
    }
    return pluginId
  }

  function pluginIcon(pluginId) {
    var icons = {
      "omarchy.menu": "󰀻",
      "omarchy.workspaces": "󰈯",
      "omarchy.active-window": "󰈹",
      "omarchy.clock": "󰥔",
      "omarchy.indicators": "󰍹",
      "omarchy.keyboard-layout": "󰌌",
      "omarchy.weather": "󰅐",
      "omarchy.system-update": "󰏗",
      "omarchy.tray": "󰩻",
      "omarchy.agents": "󰚩",
      "omarchy.bluetooth": "󰂯",
      "omarchy.network": "󰤨",
      "omarchy.audio": "󰕾",
      "omarchy.monitor": "󰍹",
      "omarchy.power": "󰤃"
    }
    return icons[pluginId] || "󰒓"
  }

  // ---- Timer ----

  Timer {
    interval: 5 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.loadConfig()
  }

  // ---- Panel UI ----

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(500))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "1") root.activeTab = 0
        else if (t === "2") root.activeTab = 1
        else if (t === "3") root.activeTab = 2
        else if (t === "4") root.activeTab = 3
        else if (t === "5") root.activeTab = 4
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: contentColumn
          width: scroll.width
          spacing: Style.space(10)

          // ---- Hero ----
          Item {
            width: parent.width
            height: heroRow.implicitHeight

            Row {
              id: heroRow
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰒓"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: 32
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Bar Manager"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: 24
                font.bold: true
              }
            }
          }

          // ---- Tab bar ----
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(4)

            Repeater {
              model: ["Left", "Center", "Right", "Add", "Bar"]

              Rectangle {
                required property string modelData
                required property int index
                width: tabLabel.implicitWidth + Style.space(20)
                height: Style.space(28)
                radius: Style.cornerRadius
                color: root.activeTab === index
                  ? Color.accent
                  : (tabMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent")

                Text {
                  id: tabLabel
                  anchors.centerIn: parent
                  text: modelData
                  color: root.activeTab === index ? "white" : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 1
                  font.bold: root.activeTab === index
                }

                MouseArea {
                  id: tabMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.activeTab = index
                }
              }
            }
          }

          // Hairline
          Rectangle {
            width: parent.width
            height: Style.spacing.hairline
            color: root.contentForeground
            opacity: 0.12
          }

          // Error text
          Text {
            visible: root.errorText !== ""
            width: parent.width
            text: root.errorText
            color: "#f44336"
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            font.italic: true
            wrapMode: Text.Wrap
          }

          // Diff preview
          Column {
            visible: root.hasChanges && root.diff.length > 0
            width: parent.width
            spacing: Style.space(4)

            Text {
              text: "PENDING CHANGES (" + root.diff.length + ")"
              color: Color.accent
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            Repeater {
              model: root.diff
              Text {
                required property string modelData
                text: "  • " + modelData
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }

            // Save / Discard buttons
            Row {
              spacing: Style.space(6)

              Rectangle {
                width: saveLabel.implicitWidth + Style.space(30)
                height: Style.space(32)
                radius: Style.cornerRadius
                color: saveMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Color.accent

                Text {
                  id: saveLabel
                  anchors.centerIn: parent
                  text: "Save"
                  color: "white"
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                MouseArea {
                  id: saveMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.saveConfig()
                }
              }

              Rectangle {
                width: discardLabel.implicitWidth + Style.space(30)
                height: Style.space(32)
                radius: Style.cornerRadius
                color: "transparent"
                border.width: 1
                border.color: Qt.darker(root.contentForeground, 1.4)

                Text {
                  id: discardLabel
                  anchors.centerIn: parent
                  text: "Discard"
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.body
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.loadConfig()
                }
              }
            }
          }

          // ================================================================
          //  TAB 0-2: SECTION LISTS (Left / Center / Right)
          // ================================================================
          Repeater {
            model: ["left", "center", "right"]

            Column {
              required property string modelData
              required property int index
              visible: root.activeTab === index
              width: parent.width
              spacing: Style.space(6)

              property string sectionName: modelData

              Text {
                text: sectionName.toUpperCase() + " SECTION"
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.bold: true
              }

              Repeater {
                model: root.sectionEntries(sectionName)

                Rectangle {
                  required property var modelData
                  required property int index
                  width: parent.width
                  height: pluginRow.implicitHeight + Style.space(10)
                  radius: Style.cornerRadius
                  color: pluginMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent"

                  property string pluginId: Model.entryId(modelData)

                  Row {
                    id: pluginRow
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(10)
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Text {
                      text: root.pluginIcon(pluginId)
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      width: parent.width - Style.space(6) - Style.space(80)
                      text: root.pluginDisplayName(pluginId)
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                      anchors.verticalCenter: parent.verticalCenter
                      elide: Text.ElideRight
                    }

                    // Move up
                    Rectangle {
                      width: Style.space(20)
                      height: Style.space(20)
                      radius: Style.space(10)
                      color: upMouse.containsMouse ? Qt.darker(root.contentForeground, 1.4) : "transparent"
                      anchors.verticalCenter: parent.verticalCenter
                      visible: index > 0

                      Text {
                        anchors.centerIn: parent
                        text: "↑"
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                      }
                      MouseArea {
                        id: upMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.reorderPlugin(pluginId, sectionName, -1)
                      }
                    }

                    // Move down
                    Rectangle {
                      width: Style.space(20)
                      height: Style.space(20)
                      radius: Style.space(10)
                      color: downMouse.containsMouse ? Qt.darker(root.contentForeground, 1.4) : "transparent"
                      anchors.verticalCenter: parent.verticalCenter
                      visible: index < root.sectionEntries(sectionName).length - 1

                      Text {
                        anchors.centerIn: parent
                        text: "↓"
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                      }
                      MouseArea {
                        id: downMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.reorderPlugin(pluginId, sectionName, 1)
                      }
                    }

                    // Settings
                    Rectangle {
                      width: Style.space(20)
                      height: Style.space(20)
                      radius: Style.space(10)
                      color: settingsMouse.containsMouse ? Qt.darker(root.contentForeground, 1.4) : "transparent"
                      anchors.verticalCenter: parent.verticalCenter
                      visible: pluginId !== "omarchy.tray"

                      Text {
                        anchors.centerIn: parent
                        text: "⚙"
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                      }
                      MouseArea {
                        id: settingsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.editingPluginId = pluginId
                          root.editingPluginSection = sectionName
                          root.editingPluginSettings = root.pluginSettings(pluginId, sectionName)
                        }
                      }
                    }

                    // Remove
                    Rectangle {
                      width: Style.space(20)
                      height: Style.space(20)
                      radius: Style.space(10)
                      color: removeMouse.containsMouse ? "#f44336" : "transparent"
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: removeMouse.containsMouse ? "white" : root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                      }
                      MouseArea {
                        id: removeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.removePlugin(pluginId, sectionName)
                      }
                    }
                  }

                  MouseArea {
                    id: pluginMouse
                    anchors.fill: parent
                    hoverEnabled: true
                  }
                }
              }

              Text {
                visible: root.sectionEntries(sectionName).length === 0
                width: parent.width
                text: "No plugins in this section"
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                font.italic: true
                horizontalAlignment: Text.AlignHCenter
              }

              // Move to other sections
              Row {
                spacing: Style.space(4)
                visible: root.sectionEntries(sectionName).length > 0

                Text {
                  text: "Move all to:"
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }

                Repeater {
                  model: ["left", "center", "right"]

                  Rectangle {
                    required property string modelData
                    visible: modelData !== sectionName
                    width: moveToLabel.implicitWidth + Style.space(12)
                    height: Style.space(22)
                    radius: Style.cornerRadius
                    color: moveToMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent"
                    border.width: 1
                    border.color: Qt.darker(root.contentForeground, 1.4)

                    Text {
                      id: moveToLabel
                      anchors.centerIn: parent
                      text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      id: moveToMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        // Move all plugins from current section to target
                        var entries = root.sectionEntries(sectionName)
                        for (var i = entries.length - 1; i >= 0; i--) {
                          root.movePlugin(Model.entryId(entries[i]), sectionName, modelData)
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // ================================================================
          //  TAB 3: ADD PLUGIN
          // ================================================================
          Column {
            visible: root.activeTab === 3
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: "ADD PLUGIN"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            // Target section selector
            Row {
              spacing: Style.space(6)

              Text {
                text: "Add to:"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }

              Repeater {
                model: ["left", "center", "right"]

                Rectangle {
                  required property string modelData
                  width: secLabel.implicitWidth + Style.space(16)
                  height: Style.space(24)
                  radius: Style.cornerRadius
                  color: root.addTargetSection === modelData ? Color.accent : "transparent"
                  border.width: 1
                  border.color: root.addTargetSection === modelData ? Color.accent : Qt.darker(root.contentForeground, 1.4)

                  Text {
                    id: secLabel
                    anchors.centerIn: parent
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    color: root.addTargetSection === modelData ? "white" : root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addTargetSection = modelData
                  }
                }
              }
            }

            Repeater {
              model: root.pluginsNotInLayout()

              Rectangle {
                required property string modelData
                width: parent.width
                height: addRow.implicitHeight + Style.space(10)
                radius: Style.cornerRadius
                color: addMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent"

                Row {
                  id: addRow
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(10)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(6)

                  Text {
                    text: root.pluginIcon(modelData)
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    width: parent.width - Style.space(6) - Style.space(80)
                    text: root.pluginDisplayName(modelData)
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Rectangle {
                    width: addBtnLabel.implicitWidth + Style.space(16)
                    height: Style.space(24)
                    radius: Style.cornerRadius
                    color: Color.accent
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      id: addBtnLabel
                      anchors.centerIn: parent
                      text: "+ Add"
                      color: "white"
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }
                }

                MouseArea {
                  id: addMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.addPlugin(modelData, root.addTargetSection)
                }
              }
            }

            Text {
              visible: root.pluginsNotInLayout().length === 0
              width: parent.width
              text: "All installed plugins are already in the layout"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              font.italic: true
              horizontalAlignment: Text.AlignHCenter
            }
          }

          // ================================================================
          //  TAB 4: BAR SETTINGS
          // ================================================================
          Column {
            visible: root.activeTab === 4
            width: parent.width
            spacing: Style.space(10)

            Text {
              text: "BAR SETTINGS"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
              font.bold: true
            }

            // Position
            Column {
              width: parent.width
              spacing: Style.space(4)

              Text {
                text: "POSITION"
                color: Qt.darker(root.contentForeground, 1.4)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
                font.bold: true
              }

              Row {
                spacing: Style.space(6)

                Repeater {
                  model: ["top", "bottom", "left", "right"]

                  Rectangle {
                    required property string modelData
                    width: posLabel.implicitWidth + Style.space(20)
                    height: Style.space(32)
                    radius: Style.cornerRadius
                    color: (currentConfig && currentConfig.bar && currentConfig.bar.position === modelData)
                      ? Color.accent
                      : (posMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent")
                    border.width: 1
                    border.color: (currentConfig && currentConfig.bar && currentConfig.bar.position === modelData)
                      ? Color.accent
                      : Qt.darker(root.contentForeground, 1.4)

                    Text {
                      id: posLabel
                      anchors.centerIn: parent
                      text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                      color: (currentConfig && currentConfig.bar && currentConfig.bar.position === modelData)
                        ? "white"
                        : root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.body
                    }

                    MouseArea {
                      id: posMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.setBarPosition(modelData)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
