import { StatusBar } from "expo-status-bar";
import { useCallback, useState } from "react";
import {
  ActivityIndicator,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";

const BASE_URL = "https://api.test.mxlabs.cloud:8443";
const ALIVE_PATH = "/alive";

type RequestState = "idle" | "loading" | "success" | "error";

interface AliveResult {
  status: number;
  ok: boolean;
  body: string;
  durationMs: number;
  url: string;
}

export default function App() {
  const [state, setState] = useState<RequestState>("idle");
  const [result, setResult] = useState<AliveResult | null>(null);
  const [errorMsg, setErrorMsg] = useState<string>("");

  const testAlive = useCallback(async () => {
    setState("loading");
    setResult(null);
    setErrorMsg("");

    const url = `${BASE_URL}${ALIVE_PATH}`;
    const start = Date.now();

    try {
      const response = await fetch(url, {
        method: "GET",
        headers: { Accept: "application/json, text/plain, */*" },
      });

      const body = await response.text();
      const durationMs = Date.now() - start;

      setResult({ status: response.status, ok: response.ok, body, durationMs, url });
      setState("success");
    } catch (err: unknown) {
      setErrorMsg(err instanceof Error ? err.message : String(err));
      setState("error");
    }
  }, []);

  const statusColor =
    state === "success" && result?.ok
      ? "#22c55e"
      : state === "error" || (state === "success" && !result?.ok)
      ? "#ef4444"
      : "#6b7280";

  return (
    <View style={styles.container}>
      <StatusBar style="auto" />

      <Text style={styles.title}>TSL Cert — /alive Test</Text>
      <Text style={styles.subtitle}>{BASE_URL}{ALIVE_PATH}</Text>

      <TouchableOpacity
        style={[styles.button, state === "loading" && styles.buttonDisabled]}
        onPress={testAlive}
        disabled={state === "loading"}
        activeOpacity={0.8}
      >
        {state === "loading" ? (
          <ActivityIndicator color="#fff" />
        ) : (
          <Text style={styles.buttonText}>Test /alive</Text>
        )}
      </TouchableOpacity>

      {state !== "idle" && (
        <ScrollView style={styles.resultBox} contentContainerStyle={styles.resultContent}>
          <View style={[styles.badge, { backgroundColor: statusColor }]}>
            <Text style={styles.badgeText}>
              {state === "loading"
                ? "Sending…"
                : state === "error"
                ? "Network Error"
                : result?.ok
                ? `${result.status} OK`
                : `${result?.status} Failed`}
            </Text>
          </View>

          {state === "error" && (
            <Text style={styles.errorText}>{errorMsg}</Text>
          )}

          {state === "success" && result && (
            <>
              <Row label="URL" value={result.url} />
              <Row label="Status" value={String(result.status)} />
              <Row label="Duration" value={`${result.durationMs} ms`} />
              <Text style={styles.label}>Response Body</Text>
              <Text style={styles.body}>{result.body || "(empty)"}</Text>
            </>
          )}
        </ScrollView>
      )}
    </View>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.row}>
      <Text style={styles.label}>{label}</Text>
      <Text style={styles.value}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#f8fafc",
    paddingTop: 72,
    paddingHorizontal: 24,
    alignItems: "center",
  },
  title: {
    fontSize: 22,
    fontWeight: "700",
    color: "#0f172a",
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 13,
    color: "#64748b",
    marginBottom: 32,
    fontFamily: "monospace",
  },
  button: {
    backgroundColor: "#3b82f6",
    paddingVertical: 14,
    paddingHorizontal: 40,
    borderRadius: 10,
    minWidth: 160,
    alignItems: "center",
  },
  buttonDisabled: {
    backgroundColor: "#93c5fd",
  },
  buttonText: {
    color: "#fff",
    fontSize: 16,
    fontWeight: "600",
  },
  resultBox: {
    marginTop: 28,
    width: "100%",
    backgroundColor: "#fff",
    borderRadius: 12,
    borderWidth: 1,
    borderColor: "#e2e8f0",
    maxHeight: 380,
  },
  resultContent: {
    padding: 16,
  },
  badge: {
    alignSelf: "flex-start",
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 20,
    marginBottom: 16,
  },
  badgeText: {
    color: "#fff",
    fontWeight: "700",
    fontSize: 13,
  },
  row: {
    marginBottom: 10,
  },
  label: {
    fontSize: 11,
    fontWeight: "600",
    color: "#94a3b8",
    textTransform: "uppercase",
    letterSpacing: 0.6,
    marginBottom: 2,
  },
  value: {
    fontSize: 14,
    color: "#1e293b",
    fontFamily: "monospace",
  },
  body: {
    fontSize: 13,
    color: "#334155",
    fontFamily: "monospace",
    backgroundColor: "#f1f5f9",
    padding: 10,
    borderRadius: 6,
    marginTop: 2,
  },
  errorText: {
    fontSize: 13,
    color: "#ef4444",
    fontFamily: "monospace",
  },
});
