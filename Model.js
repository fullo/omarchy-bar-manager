// Model.js — shell.json read/write/validate helpers for Bar Manager

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
        for (var j = 0; j < newIds.length; j++) {
            if (oldIds.indexOf(newIds[j]) === -1) changes.push("Add " + newIds[j] + " to " + s)
        }
        for (var k = 0; k < oldIds.length; k++) {
            if (newIds.indexOf(oldIds[k]) === -1) changes.push("Remove " + oldIds[k] + " from " + s)
        }
        var commonOld = oldIds.filter(function(id) { return newIds.indexOf(id) >= 0 })
        var commonNew = newIds.filter(function(id) { return oldIds.indexOf(id) >= 0 })
        if (JSON.stringify(commonOld) !== JSON.stringify(commonNew)) {
            changes.push("Reorder plugins in " + s)
        }
    }
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

// Parse setting() calls from QML source to discover available settings.
// Returns array of { key, defaultValue } objects.
function parseSettingsFromSource(source) {
    var settings = []
    var seen = {}
    // Match setting("key", defaultValue) patterns
    var regex = /setting\s*\(\s*"([^"]+)"\s*,\s*([^)]+)\)/g
    var match
    while ((match = regex.exec(source)) !== null) {
        var key = match[1]
        if (seen[key]) continue
        seen[key] = true
        var rawDefault = match[2].trim()
        var defaultValue = rawDefault
        // Normalize common defaults
        if (rawDefault === "true") defaultValue = true
        else if (rawDefault === "false") defaultValue = false
        else if (/^-?\d+(\.\d+)?$/.test(rawDefault)) defaultValue = Number(rawDefault)
        else if (rawDefault === '""' || rawDefault === "''") defaultValue = ""
        settings.push({ key: key, defaultValue: defaultValue })
    }
    return settings
}

// Merge discovered settings with current entry settings.
// Discovered settings fill in missing keys with defaults.
function mergeWithDiscoveredSettings(entry, discoveredSettings) {
    var result = entrySettings(entry)
    for (var i = 0; i < discoveredSettings.length; i++) {
        var s = discoveredSettings[i]
        if (result[s.key] === undefined || result[s.key] === null || result[s.key] === "") {
            result[s.key] = s.defaultValue
        }
    }
    return result
}
