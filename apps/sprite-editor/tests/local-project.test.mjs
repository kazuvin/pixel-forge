import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import {
  parseProjectArguments,
  resolveInsideRepository,
} from "../server/local-project.mjs";

const repositoryRoot = path.resolve("/tmp/pixel-forge");

test("default project opens the generated rock golem asset", () => {
  const project = parseProjectArguments([], repositoryRoot);

  assert.equal(
    project.manifestPath,
    path.join(
      repositoryRoot,
      "examples/sprites/rock-golem/rock-golem.sprite.json",
    ),
  );
  assert.equal(
    project.sourcePath,
    path.join(
      repositoryRoot,
      "examples/sprites/rock-golem/rock-golem.parts.png",
    ),
  );
  assert.equal(
    project.outputPath,
    path.join(repositoryRoot, "examples/sprites/rock-golem/output"),
  );
});

test("project arguments resolve paths relative to the repository", () => {
  const project = parseProjectArguments(
    [
      "--manifest",
      "examples/sprites/custom/custom.sprite.json",
      "--source",
      "examples/sprites/custom/custom.parts.png",
      "--output",
      "build/custom",
    ],
    repositoryRoot,
  );

  assert.equal(
    project.manifestPath,
    path.join(
      repositoryRoot,
      "examples/sprites/custom/custom.sprite.json",
    ),
  );
  assert.equal(
    project.sourcePath,
    path.join(repositoryRoot, "examples/sprites/custom/custom.parts.png"),
  );
  assert.equal(
    project.outputPath,
    path.join(repositoryRoot, "build/custom"),
  );
});

test("local API never accepts paths outside the repository", () => {
  assert.throws(
    () => resolveInsideRepository(repositoryRoot, "../outside.json", "manifest"),
    /manifest must stay inside the repository/,
  );
  assert.throws(
    () =>
      parseProjectArguments(
        ["--manifest", "/private/tmp/outside.sprite.json"],
        repositoryRoot,
      ),
    /manifest must stay inside the repository/,
  );
});

test("unknown and incomplete arguments fail with an actionable error", () => {
  assert.throws(
    () => parseProjectArguments(["--unknown"], repositoryRoot),
    /unknown option --unknown/,
  );
  assert.throws(
    () => parseProjectArguments(["--source"], repositoryRoot),
    /--source requires a path/,
  );
});
