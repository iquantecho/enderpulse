#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const source = fs.readFileSync(new URL("../EnderPulseLogic.js", import.meta.url), "utf8");
const logic = {};
vm.runInNewContext(source, logic, { filename: "EnderPulseLogic.js" });

assert.equal(logic.safeInstanceKey("bar HDMI-A-1/source"), "bar%20HDMI-A-1%2Fsource");
assert.equal(logic.safeInstanceKey(""), "default");
assert.notEqual(logic.safeInstanceKey("a/b"), logic.safeInstanceKey("a_b"));
assert.equal(logic.safeSourceName(" @DEFAULT_SOURCE@ ", "auto"), "@DEFAULT_SOURCE@");
for (const source of ["", "\n[input]\n", "a\nb", "a\0b"])
    assert.equal(logic.safeSourceName(source, "auto"), "auto");

const values = new Array(4).fill(0);
const state = { count: 0, strongest: 0, pending: false };
assert.equal(logic.parseCavaFrame("0;250;1000;1250", 4, values, state, 0), true);
assert.deepEqual(values, [0, 0.25, 1, 1]);
assert.deepEqual(state, { count: 4, strongest: 1, pending: true });

state.pending = false;
assert.equal(logic.parseCavaFrame("noise", 4, values, state, 0), false);
assert.equal(state.pending, false);

assert.equal(logic.parseCavaFrame("1;2;3;4;5", 3, values, state, 0), true);
assert.deepEqual(values.slice(0, 3), [0.001, 0.002, 0.003]);
assert.equal(state.count, 3);

assert.equal(logic.parseCavaFrame("20;35;36;800", 4, values, state, 0.035), true);
assert.deepEqual(values, [0, 0, 0.036, 0.8]);
assert.equal(state.strongest, 0.8);

// A bad frame must leave the last complete pending frame intact.
for (const frame of ["-12;0", "1x2;0", "1;;2", ";1", "1.5;0", "9".repeat(1000)]) {
    const previousValues = [...values];
    const previousState = { ...state };
    assert.equal(logic.parseCavaFrame(frame, 4, values, state, 0), false, frame);
    assert.deepEqual(values, previousValues);
    assert.deepEqual(state, previousState);
}
assert.equal(logic.parseCavaFrame("0;1000;\r", 4, values, state, 0), true);
assert.equal(state.count, 2);

assert.deepEqual(JSON.parse(JSON.stringify(logic.sourceProfile("microphone", "pipewire", "stale"))),
    { audioTarget: "microphone", audioBackend: "auto", customAudioSource: "" });
assert.equal(logic.sourceProfile("custom", "pipewire", " 123 ").customAudioSource, "123");

const builtIns = [{ id: "builtin_output", audioTarget: "system", name: "System output" }];
const saved = [
    { id: "builtin_output", audioTarget: "system", mode: "braille", sensitivity: 200 },
    { id: "my_output", audioTarget: "system", mode: "radial" },
    { id: "my_mic", audioTarget: "microphone", smoothing: 12 }
];
const normalized = logic.ensureBuiltInProfiles(saved, builtIns);
assert.equal(normalized.length, 3);
assert.equal(normalized[0].mode, "braille");
assert.equal(normalized[0].sensitivity, 200);
assert.equal(normalized[1], saved[1]);
assert.equal(normalized[2], saved[2]);
assert.equal(JSON.stringify(logic.ensureBuiltInProfiles(normalized, builtIns)), JSON.stringify(normalized));
assert.equal(saved[0].name, undefined, "normalization must not mutate saved data");

console.log("EnderPulse executable logic tests passed");
