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
          // Autocorrect rewrites usernames as they are typed — "jdoe"
          // becomes "Joe" — and the failure surfaces later as "unknown
          // user", far from its cause.
          autoCorrect={false}
          // Offers the saved account instead of generic keyboard
          // suggestions.
          textContentType="username"
          value={username}
          onChangeText={setUsername}
          style={styles.input}
        />
        <TextInput
          testID="password"
          accessibilityLabel="Password"
          placeholder="Password"
          secureTextEntry
          returnKeyType="go"
          onSubmitEditing={onSubmit}
          value={password}
          onChangeText={setPassword}
          style={styles.input}
        />
        {/*
         * The error was rendered but never announced: a screen-reader user
         * pressed Sign in, nothing spoke, and the form appeared to do
         * nothing at all. `alert` plus a polite live region make VoiceOver
         * and TalkBack read it when it appears.
         *
         * The node stays mounted with a reserved height even when empty —
         * remounting it per error would re-announce identical text and
         * shift the layout under the user's finger.
         */}
        <Text
          testID="error"
          accessibilityRole="alert"
          accessibilityLiveRegion="polite"
          style={styles.error}
        >
          {error}
        </Text>
        <Button testID="submit" title="Sign in" onPress={onSubmit} />
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

// Part of the 2026-07 synchronized release baseline.
