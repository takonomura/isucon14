import { randomBytes } from "node:crypto";

export const secureRandomStr = (length: number): string =>
  randomBytes(length).toString("hex");
