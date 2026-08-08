import fs from "fs";
import path from "path";

const DATA_DIR = path.join(process.cwd(), "data");

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

// Serialize writes per file so concurrent requests can't corrupt the JSON.
const writeQueues = new Map<string, Promise<void>>();

export function readJSON<T>(fileName: string, seed: T): T {
  ensureDataDir();
  const filePath = path.join(DATA_DIR, fileName);

  if (!fs.existsSync(filePath)) {
    fs.writeFileSync(filePath, JSON.stringify(seed, null, 2));
    return seed;
  }

  try {
    const raw = fs.readFileSync(filePath, "utf-8");
    return JSON.parse(raw) as T;
  } catch {
    return seed;
  }
}

export function writeJSON<T>(fileName: string, data: T): Promise<void> {
  ensureDataDir();
  const filePath = path.join(DATA_DIR, fileName);

  const previous = writeQueues.get(fileName) || Promise.resolve();
  const next = previous
    .catch(() => {})
    .then(() => fs.promises.writeFile(filePath, JSON.stringify(data, null, 2)));

  writeQueues.set(fileName, next);
  return next;
}
