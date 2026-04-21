import { getPreferenceValues, showToast, Toast } from "@raycast/api";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

// MARK: - JSON Types

export interface AnalyzeItem {
  name: string;
  sizeMB: number;
  priority: string;
  profile: string;
  path: string;
  category: string;
  action: string;
  warning?: string;
}

export interface AnalyzeJSON {
  schemaVersion: string;
  command: string;
  timestamp: string;
  totalSizeMB: number;
  itemCount: number;
  items: AnalyzeItem[];
}

export interface CleanItem {
  name: string;
  sizeMB: number;
  priority: string;
  profile: string;
  path: string;
  category: string;
  action: string;
  warning?: string;
  requiresAppClosed: boolean;
}

export interface CleanJSON {
  schemaVersion: string;
  command: string;
  mode: string;
  timestamp: string;
  profile: string;
  totalSizeMB: number;
  itemCount: number;
  items: CleanItem[];
}

export interface DoctorCheck {
  name: string;
  status: "PASS" | "WARN" | "FAIL" | "INFO";
  detail: string;
  recommendation?: string;
}

// MARK: - Utilities

interface Preferences {
  pulsePath?: string;
}

export function getPulsePath(): string {
  const prefs = getPreferenceValues<Preferences>();
  return prefs.pulsePath || "/usr/local/bin/pulse";
}

export async function runPulseCommand(
  pulsePath: string,
  args: string[],
): Promise<string> {
  try {
    const { stdout } = await execAsync(`"${pulsePath}" ${args.join(" ")}`);
    return stdout;
  } catch (error) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Pulse CLI failed",
      message: error instanceof Error ? error.message : "Unknown error",
    });
    throw error;
  }
}

export function parseAnalyzeJSON(output: string): AnalyzeJSON {
  return JSON.parse(output) as AnalyzeJSON;
}

export function parseCleanJSON(output: string): CleanJSON {
  return JSON.parse(output) as CleanJSON;
}
