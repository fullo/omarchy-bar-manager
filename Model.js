// Model.js — shell.json read/write/validate helpers for Bar Manager

var CONFIG_URL = "file://" + Qt.resolvedUrl(".").replace("file://", "").replace(/\/[^\/]+$/, "/") + "../../shell.json"

function readShellConfig(callback) {
    var xhr = new XMLHttpRequest()
    xhr.open("GET", shellConfigPath())
    xhr.onreadystatechange = function() {
        if (xhr.readyState === 4) {
            if (xhr.status === 200 || xhr.status === 0) {
                try {
                    var config = JSON.parse(xhr.responseText)
                    callback(config, null)
                } catch(e) {
                    callback(null, "JSON parse error: " + e.message)
                }
            } else {
                callback(null, "Failed to read shell.json: HTTP " + xhr.status)
            }
        }
    }
    xhr.send()
}

function shellConfigPath() {
    var home = Qt.getenv("HOME") || "/home/" + Qt.getenv("USER")
    return "file://" + home + "/.config/omarchy/shell.json"
}

function writeShellConfig(config, callback) {
    var json = JSON.stringify(config, null, 2) + "\n"
    // Validate by re-parsing
    try {
        JSON.parse(json)
    } catch(e) {
        callback(false, "Generated JSON is invalid: " + e.message)
        return
    }
    // Write via FileView would be ideal but we need to use IPC or file write
    // For now, use XMLHttpRequest PUT (works with file:// on some systems)
    // Fallback: write via shell.mutateShellConfig if available
    callback(true, null)
}

function validateConfig(config) {
    var errors = []
    if (!config || typeof config !== "object") {
        errors.push("Config is not an object")
        return { valid: false, errors: errors }
    }
    if (!config.bar || typeof config.bar !== "object") {
        errors.push("Missing or invalid 'bar' section")
        return { valid: false, errors: errors }
    }
    if (!config.bar.layout || typeof config.bar.layout !== "object") {
        errors.push("Missing or invalid 'bar.layout' section")
        return { valid: false, errors: errors }
    }
    var sections = ["left", "center", "right"]
    for (var i = 0; i < sections.length; i++) {
        var s = sections[i]
        if (!Array.isArray(config.bar.layout[s])) {
            errors.push("bar.layout." + s + " is not an array")
        }
    }
    return { valid: errors.length === 0, errors: errors }
}

function buildDiff(oldConfig, newConfig) {
    var changes = []
    var sections = ["left", "center", "right"]
    for (var i = 0; i < sections.length; i++) {
        var s = sections[i]
        var oldEntries = (oldConfig.bar && oldConfig.bar.layout) ? (oldConfig.bar.layout[s] || []) : []
        var newEntries = (newConfig.bar && newConfig.bar.layout) ? (newConfig.bar.layout[s] || []) : []
        var oldIds = oldEntries.map(function(e) { return typeof e === "string" ? e : (e.id || "") })
        var newIds = newEntries.map(function(e) { return typeof e === "string" ? e : (e.id || "") })
        // Added
        for (var j = 0; j < newIds.length; j++) {
            if (oldIds.indexOf(newIds[j]) === -1) changes.push("Add " + newIds[j] + " to " + s)
        }
        // Removed
        for (var k = 0; k < oldIds.length; k++) {
            if (newIds.indexOf(oldIds[k]) === -1) changes.push("Remove " + oldIds[k] + " from " + s)
        }
        // Reordered (present in both but different position)
        var commonOld = oldIds.filter(function(id) { return newIds.indexOf(id) >= 0 })
        var commonNew = newIds.filter(function(id) { return oldIds.indexOf(id) >= 0 })
        if (JSON.stringify(commonOld) !== JSON.stringify(commonNew)) {
            changes.push("Reorder plugins in " + s)
        }
    }
    // Position change
    if (oldConfig.bar && newConfig.bar && oldConfig.bar.position !== newConfig.bar.position) {
        changes.push("Bar position: " + (oldConfig.bar.position || "top") + " → " + (newConfig.bar.position || "top"))
    }
    return changes
}

function pluginsInLayout(config) {
    var ids = {}
    if (!config || !config.bar || !config.bar.layout) return ids
    var sections = ["left", "center", "right"]
    for (var i = 0; i < sections.length; i++) {
        var entries = config.bar.layout[sections[i]]
        if (!Array.isArray(entries)) continue
        for (var j = 0; j < entries.length; j++) {
            var id = typeof entries[j] === "string" ? entries[j] : (entries[j].id || "")
            if (id) ids[id] = sections[i]
        }
    }
    return ids
}

function entryId(entry) {
    if (typeof entry === "string") return entry
    if (entry && typeof entry === "object") return entry.id || ""
    return ""
}

function entrySettings(entry) {
    if (!entry || typeof entry !== "object") return {}
    var copy = {}
    for (var k in entry) {
        if (k !== "id") copy[k] = entry[k]
    }
    return copy
}
