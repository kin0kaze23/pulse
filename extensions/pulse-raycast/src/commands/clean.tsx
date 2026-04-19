import { List, Action, ActionPanel, useExec } from "@raycast/api";
import { getPulsePath, runPulseCommand, parseCleanJSON, CleanItem } from "../utils";

interface CleanData {
  items: CleanItem[];
  totalSizeMB: number;
  itemCount: number;
  profile: string;
}

export default function CleanCommand() {
  const { isLoading, data, revalidate } = useExec<CleanData>(
    "clean",
    async () => {
      const pulsePath = getPulsePath();
      const output = await runPulseCommand(pulsePath, ["clean", "--dry-run", "--json"]);
      const parsed = parseCleanJSON(output);
      return {
        items: parsed.items,
        totalSizeMB: parsed.totalSizeMB,
        itemCount: parsed.itemCount,
        profile: parsed.profile,
      };
    },
    { executeImmediately: true }
  );

  if (isLoading || !data) {
    return (
      <List isLoading={true}>
        <List.EmptyView icon="🧹" title="Scanning cleanup candidates..." />
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
      navigationTitle="Pulse — Preview Cleanup"
      navigationSubtitle={`${data.itemCount} items · ${totalSize}`}
    >
      {data.items.map((item) => (
        <List.Item
          key={item.name}
          icon={getActionIcon(item.action)}
          title={item.name}
          subtitle={`${formatSize(item.sizeMB)} · ${item.action}`}
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
              {item.warning && (
                <Action.ShowToast
                  title="Warning"
                  message={item.warning}
                  style="warning"
                />
              )}
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}

function getActionIcon(action: string): string {
  if (action.startsWith("command:")) {
    return "⚙️";
  }
  return "🗑️";
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
