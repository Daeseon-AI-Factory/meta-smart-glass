import { test, expect } from "bun:test";
import { parseSuggestions } from "./parse";

test("parses clean JSON and preserves valid tones", () => {
  const raw = JSON.stringify({
    suggestions: [
      { text: "Sure, let me pull up the dashboard.", tone: "professional" },
      { text: "Yeah, give me a sec.", tone: "casual" },
    ],
  });
  const out = parseSuggestions(raw);
  expect(out).toEqual([
    { text: "Sure, let me pull up the dashboard.", tone: "professional" },
    { text: "Yeah, give me a sec.", tone: "casual" },
  ]);
});

test("extracts the JSON object even if wrapped in prose", () => {
  const raw = 'Here you go:\n{"suggestions":[{"text":"One moment, please.","tone":"safe"}]}\nHope that helps!';
  expect(parseSuggestions(raw)).toEqual([{ text: "One moment, please.", tone: "safe" }]);
});

test("normalizes an unknown tone to 'safe'", () => {
  const raw = '{"suggestions":[{"text":"Hi there.","tone":"enthusiastic"}]}';
  expect(parseSuggestions(raw)).toEqual([{ text: "Hi there.", tone: "safe" }]);
});

test("drops entries with non-string or empty text", () => {
  const raw = JSON.stringify({
    suggestions: [
      { text: "", tone: "casual" },
      { text: 42, tone: "casual" },
      { text: "Valid one.", tone: "professional" },
    ],
  });
  expect(parseSuggestions(raw)).toEqual([{ text: "Valid one.", tone: "professional" }]);
});

test("throws when there is no JSON object", () => {
  expect(() => parseSuggestions("no json here")).toThrow();
});

test("throws when 'suggestions' is missing", () => {
  expect(() => parseSuggestions('{"foo":1}')).toThrow();
});

test("throws when every suggestion is invalid", () => {
  expect(() => parseSuggestions('{"suggestions":[{"text":""}]}')).toThrow();
});
