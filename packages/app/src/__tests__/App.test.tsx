/**
 * @format
 */

import { validateCredentials } from "@shomer/lib";

// Proves the app resolves @shomer/lib (Metro alias / jest moduleNameMapper)
// and shares the exact validation the web client uses.
describe("shared validation via @shomer/lib", () => {
  it("rejects a short password with the shared message", () => {
    expect(validateCredentials({ username: "alice", password: "short" })).toBe(
      "password must be at least 8 characters",
    );
  });

  it("accepts a valid pair", () => {
    expect(validateCredentials({ username: "alice", password: "wonderland8" })).toBeNull();
  });
});

// The two defects fixed here lived in props on the element tree, so the
// tests assert those rather than driving the UI.
//
// SafeAreaProvider is mocked: it measures real insets through a native
// module, and under react-test-renderer that measurement resolves after
// the Jest environment has torn down — "You are trying to `import` a file
// after the Jest environment has been torn down". Mocking it keeps the
// tree intact and removes the async work.
jest.mock("react-native-safe-area-context", () => {
  const { View } = require("react-native");
  return {
    SafeAreaProvider: ({ children }: { children: React.ReactNode }) => <View>{children}</View>,
    useSafeAreaInsets: () => ({ top: 0, bottom: 0, left: 0, right: 0 }),
  };
});

import { act, create } from "react-test-renderer";
import App from "../App";

// `create` must run inside `act` under React 19: without it the renderer
// is torn down before the tree can be read, and `.root` throws
// "Can't access .root on unmounted test renderer".
function render() {
  let tree!: ReturnType<typeof create>;
  act(() => {
    tree = create(<App />);
  });
  return tree;
}

function findByTestID(tree: ReturnType<typeof create>, id: string) {
  return tree.root.findAll((n) => n.props?.testID === id)[0];
}

describe("login screen accessibility", () => {
  it("announces the validation error to screen readers", () => {
    const tree = render();
    const error = findByTestID(tree, "error");
    // Rendered but silent before: the form looked like it did nothing.
    expect(error.props.accessibilityRole).toBe("alert");
    expect(error.props.accessibilityLiveRegion).toBe("polite");
  });

  it("does not let autocorrect rewrite the username", () => {
    const tree = render();
    const username = findByTestID(tree, "username");
    expect(username.props.autoCorrect).toBe(false);
    expect(username.props.autoCapitalize).toBe("none");
  });
});
