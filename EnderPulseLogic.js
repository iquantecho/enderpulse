function safeInstanceKey(instanceId) {
    const raw = instanceId && instanceId.length > 0 ? instanceId : "default"
    return encodeURIComponent(raw)
}

function safeSourceName(value, fallback) {
    const source = String(value ?? "")
    return source.trim() && !/[\r\n\0]/.test(source) ? source.trim() : fallback
}

function parseCavaFrame(line, bandCount, pendingValues, frameState, noiseFloor) {
    // Validate before touching a pending frame; malformed output must not animate.
    if (line.length > bandCount * 6 + 2 || !/^\d{1,5}(;\d{1,5})*;?\r?$/.test(line))
        return false

    let value = 0
    let hasDigit = false
    let count = 0
    let strongest = 0

    for (let i = 0; i <= line.length && count < bandCount; i++) {
        const code = i < line.length ? line.charCodeAt(i) : 59
        if (code >= 48 && code <= 57) {
            value = value * 10 + code - 48
            hasDigit = true
        } else if (code === 59 && hasDigit) {
            const measured = Math.max(0, Math.min(1, value / 1000))
            const target = measured <= (noiseFloor ?? 0) ? 0 : measured
            pendingValues[count++] = target
            strongest = Math.max(strongest, target)
            value = 0
            hasDigit = false
        }
    }

    if (count === 0)
        return false

    frameState.count = count
    frameState.strongest = strongest
    frameState.pending = true
    return true
}

function sourceProfile(target, backend, customSource) {
    return {
        audioTarget: target,
        audioBackend: target === "custom" || target === "system" ? backend : "auto",
        customAudioSource: target === "custom" ? String(customSource).trim() : ""
    }
}

function ensureBuiltInProfiles(current, builtIns) {
    return builtIns.map(function(profile) {
        const saved = current.find(function(candidate) { return candidate.id === profile.id })
        return Object.assign({}, saved || {}, profile)
    }).concat(current.filter(function(profile) {
        return !builtIns.some(function(builtIn) { return builtIn.id === profile.id })
    }))
}
