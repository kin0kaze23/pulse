import { List, Action, ActionPanel, Icon, Color } from "@raycast/api";
import { usePromise } from "@raycast/utils";
import { runPulseCommand, DoctorCheck } from "../utils";
import { getPulsePath } from "../utils";

function doctorChecks(): Promise<DoctorCheck[]> {
  return runPulseCommand(getPulsePath(), ["doctor", "--json"]).then(
    (output) => JSON.parse(output).checks as DoctorCheck[],
  );
}

export default function DoctorCommand() {
  const { data, isLoading } = usePromise(doctorChecks);
  const checks = (data as DoctorCheck[]) || [];

  if (isLoading) {
    return (
      <List isLoading={true}>
        <List.EmptyView icon={Icon.Hammer} title="Running Pulse Doctor..." />
      </List>
    );
  }

  const passCount = checks.filter((c) => c.status === "PASS").length;
  const warnCount = checks.filter((c) => c.status === "WARN").length;
  const failCount = checks.filter((c) => c.status === "FAIL").length;

  return (
    <List isLoading={false} navigationTitle="Pulse — Doctor">
      <List.EmptyView
        icon={{ source: Icon.CheckCircle, tintColor: Color.Green }}
        title={`${passCount} passed, ${warnCount} warnings, ${failCount} failed`}
      />
      {checks.map((check) => (
        <List.Item
          key={check.name}
          icon={{
            source: getStatusIcon(check.status),
            tintColor: getStatusColor(check.status),
          }}
          title={check.name}
          subtitle={check.detail}
          keywords={[check.status, check.recommendation || ""]}
          actions={
            check.recommendation ? (
              <ActionPanel>
                <Action.CopyToClipboard
                  title="Copy Recommendation"
                  content={check.recommendation}
                />
              </ActionPanel>
            ) : undefined
          }
        />
      ))}
    </List>
  );
}

function getStatusIcon(status: string): Icon {
  switch (status) {
    case "PASS":
      return Icon.Checkmark;
    case "FAIL":
      return Icon.XMarkCircle;
    case "WARN":
      return Icon.ExclamationMark;
    default:
      return Icon.QuestionMark;
  }
}

function getStatusColor(status: string): Color {
  switch (status) {
    case "PASS":
      return Color.Green;
    case "FAIL":
      return Color.Red;
    case "WARN":
      return Color.Yellow;
    default:
      return Color.SecondaryText;
  }
}
