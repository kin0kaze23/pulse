import { List, Action, ActionPanel, useExec } from "@raycast/api";
import { useEffect, useState } from "react";
import { getPulsePath, runPulseCommand, parseAnalyzeJSON, AnalyzeItem } from "../utils";

interface AnalyzeData {
  items: AnalyzeItem[];
  totalSizeMB: number;
  itemCount: number;
}

export default function AnalyzeCommand() {
  const { isLoading, data, revalidate } = useExec<AnalyzeData>(
    "analyze",
    async () => {
      const pulsePath = getPulsePath();
      const output = await runPulseCommand(pulsePath, ["analyze", "--json"]);
      const parsed = parseAnalyzeJSON(output);
      return {
        items: parsed.items,
        totalSizeMB: parsed.totalSizeMB,
        itemCount: parsed.itemCount,
      };
    },
    { executeImmediately: true }
  );

  if (isLoading || !data) {
    return (
      <List isLoading={true}>
        <List.EmptyView icon="🔍" title="Scanning for cleanup candidates..." />
      </List>
    );
  }

  if (data.items.length === 0) {
    return (
      <List>
        <List.EmptyView
          icon="✅"
          title="Nothing to clean"
          description="All caches are below thresholds."
        />
      </List>
    );
  }

  const totalSize =
    data.totalSizeMB >= 1024
      ? `${(data.totalSizeMB / 1024).toFixed(1)} GB`
      : `${Math.round(data.totalSizeMB)} MB`;

  return (
    <List
      isLoading={false}
      searchBarPlaceholder="Search cleanup candidates..."
      navigationTitle="Pulse — Analyze"
      navigationSubtitle={`${data.itemCount} items · ${totalSize} reclaimable`}
    >
      {data.items.map((item) => (
        <List.Item
          key={item.name}
          icon={getPriorityIcon(item.priority)}
          title={item.name}
          subtitle={`${formatSize(item.sizeMB)} · ${item.profile}`}
          keywords={[item.profile, item.category, item.priority]}
          actions={
            <ActionPanel>
              <Action.CopyToClipboard
                title="Copy Path"
                content={item.path}
              />
              <Action.OpenInBrowser
                title="Open in Finder"
                url={`file://${expandTilde(item.path)}`}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}

function getPriorityIcon(priority: string): string {
  switch (priority.toLowerCase()) {
    case "high":
      return "🟢";
    case "medium":
      return "🟡";
    case "low":
      return "🔴";
    default:
      return "⚪";
  }
}

function formatSize(mb: number): string {
  if (mb >= 1024) {
    return `${(mb / 1024).toFixed(1)} GB`;
  }
  return `${Math.round(mb)} MB`;
}

function expandTilde(path: string): string {
  return path.replace(/^~/, process.env.HOME || "");
}
