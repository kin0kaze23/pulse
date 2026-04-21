import { List, Action, ActionPanel, Icon } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { runPulseCommand, parseAnalyzeJSON, AnalyzeItem } from "../utils";
import { getPulsePath } from "../utils";

function analyzeItems(): Promise<AnalyzeItem[]> {
  return runPulseCommand(getPulsePath(), ["analyze", "--json"]).then(
    (output) => parseAnalyzeJSON(output).items,
  );
}

export default function AnalyzeCommand() {
  const { data, isLoading } = usePromise(analyzeItems);
  const items = (data as AnalyzeItem[]) || [];

  if (isLoading) {
    return (
      <List isLoading={true}>
        <List.EmptyView
          icon={Icon.MagnifyingGlass}
          title="Scanning for cleanup candidates..."
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
      navigationTitle="Pulse — Analyze"
    >
      {items.map((item) => (
        <List.Item
          key={item.name}
          icon={getPriorityIcon(item.priority)}
          title={item.name}
          subtitle={`${formatSize(item.sizeMB)} · ${item.profile}`}
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

function getPriorityIcon(priority: string): Icon {
  switch (priority.toLowerCase()) {
    case "high":
      return Icon.CircleFilled;
    default:
      return Icon.Circle;
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
