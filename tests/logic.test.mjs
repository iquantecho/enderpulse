#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const source = fs.readFileSync(new URL("../EnderPulseLogic.js", import.meta.url), "utf8");
const logic = {};
vm.runInNewContext(source, logic, { filename: "EnderPulseLogic.js" });

assert.equal(logic.safeInstanceKey("bar HDMI-A-1/source"), "bar_HDMI-A-1_source");
assert.equal(logic.safeInstanceKey(""), "default");

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

console.log("EnderPulse executable logic tests passed");
