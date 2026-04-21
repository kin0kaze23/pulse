import { List, Action, ActionPanel, Icon } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { runPulseCommand, parseCleanJSON, CleanItem } from "../utils";
import { getPulsePath } from "../utils";

function cleanItems(): Promise<CleanItem[]> {
  return runPulseCommand(getPulsePath(), ["clean", "--dry-run", "--json"]).then(
    (output) => parseCleanJSON(output).items,
  );
}

export default function CleanCommand() {
  const { data, isLoading } = usePromise(cleanItems);
  const items = (data as CleanItem[]) || [];

  if (isLoading) {
    return (
      <List isLoading={true}>
        <List.EmptyView
          icon={Icon.Trash}
          title="Scanning cleanup candidates..."
        />
      </List>
    );
  }

  if (items.length === 0) {
    return (
      <List>
        <List.EmptyView
          icon={Icon.Checkmark}
          title="Nothing to clean"
          description="All caches are below thresholds."
        />
      </List>
    );
  }

  return (
    <List
      isLoading={false}
      searchBarPlaceholder="Search cleanup candidates..."
      navigationTitle="Pulse — Preview Cleanup"
    >
      {items.map((item) => (
        <List.Item
          key={item.name}
          icon={getActionIcon(item.action)}
          title={item.name}
          subtitle={`${formatSize(item.sizeMB)} · ${item.action}`}
          keywords={[item.profile, item.category, item.priority]}
          actions={
            <ActionPanel>
              <Action.CopyToClipboard title="Copy Path" content={item.path} />
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

function getActionIcon(action: string): Icon {
  if (action.startsWith("command:")) {
    return Icon.Gear;
  }
  return Icon.Trash;
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
