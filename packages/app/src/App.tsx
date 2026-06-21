// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>

/**
 * Shomer mobile login screen.
 *
 * Reuses @shomer/lib's validateCredentials / formatError — the exact
 * same logic the React web island runs — so the two clients reject the
 * same inputs with the same messages.
 */

import { type Credentials, formatError, validateCredentials } from "@shomer/lib";
import { useState } from "react";
import { Button, StyleSheet, Text, TextInput, View } from "react-native";
import { SafeAreaProvider } from "react-native-safe-area-context";

export default function App() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  function onSubmit(): void {
    const creds: Credentials = { username, password };
    const problem = validateCredentials(creds);
    setError(problem === null ? "" : formatError(problem));
    // A valid submit would POST to the shomer-api here.
  }

  return (
    <SafeAreaProvider>
      <View style={styles.container}>
        <Text style={styles.title}>Sign in</Text>
        <TextInput
          testID="username"
          accessibilityLabel="Username"
          placeholder="Username"
          autoCapitalize="none"
          value={username}
          onChangeText={setUsername}
          style={styles.input}
        />
        <TextInput
          testID="password"
          accessibilityLabel="Password"
          placeholder="Password"
          secureTextEntry
          value={password}
          onChangeText={setPassword}
          style={styles.input}
        />
        <Text testID="error" style={styles.error}>
          {error}
        </Text>
        <Button title="Sign in" onPress={onSubmit} />
      </View>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    padding: 24,
    gap: 12,
  },
  title: {
    fontSize: 24,
    fontWeight: "600",
  },
  input: {
    borderWidth: 1,
    borderColor: "#ccc",
    borderRadius: 4,
    padding: 12,
  },
  error: {
    color: "#b00020",
    minHeight: 20,
  },
});
