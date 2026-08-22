function safeInstanceKey(instanceId) {
    const raw = instanceId && instanceId.length > 0 ? instanceId : "default"
    return raw.replace(/[^A-Za-z0-9_-]/g, "_")
}

function parseCavaFrame(line, bandCount, pendingValues, frameState, noiseFloor) {
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
