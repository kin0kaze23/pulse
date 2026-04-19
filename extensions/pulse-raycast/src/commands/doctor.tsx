import { List, Action, ActionPanel, useExec, Icon, Color } from "@raycast/api";
import { getPulsePath, runPulseCommand, DoctorCheck } from "../utils";

interface DoctorData {
  checks: DoctorCheck[];
}

export default function DoctorCommand() {
  const { isLoading, data } = useExec<DoctorData>(
    "doctor",
    async () => {
      const pulsePath = getPulsePath();
      const output = await runPulseCommand(pulsePath, ["doctor", "--json"]);
      const json = JSON.parse(output);
      return { checks: json.checks as DoctorCheck[] };
    },
    { executeImmediately: true }
  );

  if (isLoading || !data) {
    return (
      <List isLoading={true}>
        <List.EmptyView icon="🩺" title="Running Pulse Doctor..." />
      </List>
    );
  }

  const passCount = data.checks.filter((c) => c.status === "PASS").length;
  const warnCount = data.checks.filter((c) => c.status === "WARN").length;
  const failCount = data.checks.filter((c) => c.status === "FAIL").length;

  return (
    <List
      isLoading={false}
      navigationTitle="Pulse — Doctor"
      navigationSubtitle={`${passCount} passed, ${warnCount} warnings, ${failCount} failed`}
    >
      {data.checks.map((check) => (
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
                <Action.ShowToast
                  title="Recommendation"
                  message={check.recommendation!}
                  style={check.status === "FAIL" ? "failure" : "warning"}
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
      return Color.Gray;
  }
}
