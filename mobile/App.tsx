import { StatusBar } from "expo-status-bar";
import { useCallback, useState } from "react";
import {
  ActivityIndicator,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  TextInput,
  SafeAreaView,
} from "react-native";

const BASE_URL = "https://valid.test.mxlabs.cloud";

// Endpoints from README (unit-test subdomains on port 443)
const ENDPOINTS: { key: string; url: string; label?: string }[] = [
  { key: "valid", url: "https://valid.test.mxlabs.cloud", label: "valid.test" },
  { key: "expired", url: "https://expired.test.mxlabs.cloud", label: "expired.test" },
  { key: "notyet", url: "https://notyet.test.mxlabs.cloud", label: "notyet.test" },
  { key: "wronghost", url: "https://wronghost.test.mxlabs.cloud", label: "wronghost.test" },
  { key: "selfsigned", url: "https://selfsigned.test.mxlabs.cloud", label: "selfsigned.test" },
  { key: "untrustedca", url: "https://untrustedca.test.mxlabs.cloud", label: "untrustedca.test" },
  { key: "weakkey", url: "https://weakkey.test.mxlabs.cloud", label: "weakkey.test" },
  { key: "wrongusage", url: "https://wrongusage.test.mxlabs.cloud", label: "wrongusage.test" },
  { key: "wildcard", url: "https://wildcard.test.mxlabs.cloud", label: "wildcard.test" },
  { key: "revoked", url: "https://revoked.test.mxlabs.cloud", label: "revoked.test" },
  { key: "missingchain", url: "https://missingchain.test.mxlabs.cloud", label: "missingchain.test" },
];

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
  const [customUrl, setCustomUrl] = useState<string>("");

  const testEndpoint = useCallback(async (urlOrPath: string) => {
    setState("loading");
    setResult(null);
    setErrorMsg("");

    // Accept either a full URL (https://...) or a path (/alive)
    const url = urlOrPath.startsWith("http") ? urlOrPath : `${BASE_URL}${urlOrPath}`;
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
    <SafeAreaView style={styles.container}>
      <StatusBar style="auto" />

      <Text style={styles.title}>TSL Cert — Endpoint Tester</Text>
      <Text style={styles.subtitle}>{BASE_URL}</Text>

      {/* Custom URL input */}
      <View style={styles.customRow}>
        <TextInput
          style={styles.customInput}
          placeholder="https://valid.test.mxlabs.cloud"
          value={customUrl}
          onChangeText={setCustomUrl}
          autoCapitalize="none"
          autoCorrect={false}
          keyboardType="url"
          returnKeyType="go"
          onSubmitEditing={() => {
            if (customUrl.trim()) testEndpoint(customUrl.trim());
          }}
        />
        <TouchableOpacity
          style={[styles.button, styles.customTestButton, state === "loading" && styles.buttonDisabled]}
          onPress={() => customUrl.trim() && testEndpoint(customUrl.trim())}
          disabled={state === "loading" || !customUrl.trim()}
        >
          {state === "loading" ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.buttonText}>Custom URL</Text>
          )}
        </TouchableOpacity>
      </View>

      <ScrollView
        horizontal
        contentContainerStyle={styles.endpointList}
        style={{ marginBottom: 12 }}
        showsHorizontalScrollIndicator={false}
      >
        {ENDPOINTS.map((ep) => (
          <TouchableOpacity
            key={ep.key}
            style={[styles.button, state === "loading" && styles.buttonDisabled, styles.endpointButton]}
            onPress={() => testEndpoint(ep.url)}
            disabled={state === "loading"}
            activeOpacity={0.8}
          >
            {state === "loading" ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Text style={styles.buttonText}>{ep.label ?? ep.url}</Text>
            )}
          </TouchableOpacity>
        ))}
      </ScrollView>

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
    </SafeAreaView>
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
    backgroundColor: "#f6f8fb",
    paddingTop: 20,
    paddingHorizontal: 18,
    alignItems: "stretch",
  },
  title: {
    fontSize: 20,
    fontWeight: "700",
    color: "#0b1220",
    marginBottom: 6,
  },
  subtitle: {
    fontSize: 12,
    color: "#6b7280",
    marginBottom: 14,
    fontFamily: "monospace",
  },
  button: {
    backgroundColor: "#2563eb",
    paddingVertical: 10,
    paddingHorizontal: 18,
    borderRadius: 12,
    minWidth: 120,
    alignItems: "center",
    shadowColor: "#000",
    shadowOpacity: 0.12,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
    elevation: 3,
  },
  endpointButton: {
    marginRight: 10,
    minWidth: 110,
    paddingHorizontal: 12,
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
    marginTop: 18,
    width: "100%",
    backgroundColor: "#ffffff",
    borderRadius: 14,
    borderWidth: 0,
    padding: 0,
    shadowColor: "#000",
    shadowOpacity: 0.04,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
    elevation: 4,
    maxHeight: 420,
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
  endpointList: {
    paddingHorizontal: 8,
    paddingVertical: 4,
  },
  customRow: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 10,
  },
  customInput: {
    flex: 1,
    backgroundColor: "#fff",
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 10,
    marginRight: 10,
    borderWidth: 1,
    borderColor: "#e6eefc",
  },
  customTestButton: {
    minWidth: 110,
    paddingHorizontal: 14,
  },
  errorText: {
    fontSize: 13,
    color: "#ef4444",
    fontFamily: "monospace",
  },
});
