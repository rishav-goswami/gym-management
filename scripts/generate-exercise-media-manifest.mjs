import { readFileSync, writeFileSync } from "node:fs";

const sourceFile = "apps/gym_app/lib/firebase/domain/exercise_guide.dart";
const outputFile = "firebase/data/exercise-media.v1.json";
const source = readFileSync(sourceFile, "utf8");
const commit = source.match(/[a-f0-9]{40}(?=\/exercises)/)?.[0];
if (!commit) throw new Error("Unable to find the pinned exercise source commit.");

const images = [...source.matchAll(/'([^']+\/[01]\.jpg)'/g)]
  .map((match) => match[1])
  .filter((path, index, values) => values.indexOf(path) === index)
  .sort();
if (images.length === 0 || images.length % 2 !== 0) {
  throw new Error(`Expected paired exercise media, found ${images.length} images.`);
}

const manifest = {
  schemaVersion: 1,
  catalogVersion: "v1",
  sourceRepository: "https://github.com/yuhonas/free-exercise-db",
  sourceCommit: commit,
  sourceLicense: "Unlicense / public domain",
  sourceRoot: `https://raw.githubusercontent.com/yuhonas/free-exercise-db/${commit}/exercises`,
  destinationPrefix: "platform/exercise-media/v1",
  images,
};
writeFileSync(outputFile, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Wrote ${outputFile} with ${images.length} images.`);
